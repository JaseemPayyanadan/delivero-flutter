import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/use_current_location_button.dart';
import '../../../core/widgets/address_autocomplete_field.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery_route.dart';
import '../../../core/utils/route_refs.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../../data/models/food_item.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final String? customerId;
  const AddEditCustomerScreen({super.key, this.customerId});

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _discountController;
  String? _selectedRouteId;
  List<CustomerProduct> _selectedProducts = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

  bool _isActive = true;
  bool _hydratedFromProvider = false;
  bool _hydratePostFrameScheduled = false;
  String? _savedFormSignature;

  bool get _isEditMode => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _discountController = TextEditingController();
    if (!_isEditMode) {
      _savedFormSignature = _currentFormSignature();
    }
  }

  void _populateFromCustomer(Customer customer) {
    _nameController.text = customer.name;
    _ownerNameController.text = customer.ownerName ?? '';
    _phoneController.text = customer.phone;
    _addressController.text = customer.address;
    final discount = customer.discountPercentage;
    _discountController.text = (discount != null && discount > 0)
        ? discount.toString()
        : '';

    final routes = ref.read(routesProvider);
    final route = RouteRefs.routeForRef(customer.assignedRoute, routes);
    _selectedRouteId = route?.id ?? customer.assignedRoute;

    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    _quantityControllers.clear();
    _priceControllers.clear();

    _isActive = customer.isActive;
    _selectedProducts = List.from(customer.products ?? []);
    for (final p in _selectedProducts) {
      _quantityControllers[p.id] = TextEditingController(
        text: p.quantity.toString(),
      );
      if (p.customPrice != null) {
        _priceControllers[p.id] = TextEditingController(
          text: p.customPrice.toString(),
        );
      }
    }
    _savedFormSignature = _currentFormSignature();
  }

  String _currentFormSignature() {
    final productSig = _selectedProducts
        .map((p) {
          final qty = _quantityControllers[p.id]?.text ?? '';
          final price = _priceControllers[p.id]?.text ?? '';
          return '${p.id}:$qty:$price';
        })
        .join('|');
    return [
      _nameController.text.trim(),
      _ownerNameController.text.trim(),
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _discountController.text.trim(),
      _selectedRouteId ?? '',
      productSig,
      _isActive.toString(),
    ].join('::');
  }

  bool get _hasUnsavedChanges {
    final baseline = _savedFormSignature;
    if (baseline == null) return false;
    return _currentFormSignature() != baseline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _discountController.dispose();
    for (var c in _quantityControllers.values) {
      c.dispose();
    }
    for (var c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    // H7: basic phone format check
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isNotEmpty) {
      final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number looks invalid — check and try again.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
        return;
      }
    }

    final List<CustomerProduct> products = [];
    for (var sp in _selectedProducts) {
      final qty = int.tryParse(_quantityControllers[sp.id]?.text ?? '0') ?? 0;
      final price = double.tryParse(_priceControllers[sp.id]?.text ?? '');
      products.add(
        CustomerProduct(
          id: sp.id,
          name: sp.name,
          quantity: qty,
          customPrice: price,
        ),
      );
    }

    final routes = ref.read(routesProvider);
    final selectedRoute = routes.firstWhereOrNull(
      (r) => r.id == _selectedRouteId,
    );
    final assignedRouteId =
        selectedRoute?.id ??
        RouteRefs.routeIdForRef(_selectedRouteId, routes) ??
        _selectedRouteId;

    final factoryId = await ref.read(factoryIdProvider.future);
    if (factoryId == null || factoryId.isEmpty) return;
    final existingCustomer = _isEditMode
        ? ref
              .read(customersProvider)
              .firstWhereOrNull((c) => c.id == widget.customerId)
        : null;
    final existingCustomerEmail = existingCustomer?.email ?? '';

    final newCustomer = Customer(
      id: _isEditMode ? widget.customerId! : const Uuid().v4(),
      factoryId: factoryId,
      name: _nameController.text,
      ownerName: _ownerNameController.text.trim().isEmpty
          ? null
          : _ownerNameController.text.trim(),
      email: existingCustomerEmail,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      area: selectedRoute?.area ?? 'Central',
      isActive: _isActive,
      discountPercentage: double.tryParse(_discountController.text.trim()),
      assignedRoute: assignedRouteId,
      products: products,
      createdAt: _isEditMode
          ? (existingCustomer?.createdAt ?? DateTime.now())
          : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final saveFuture = _isEditMode
        ? ref.read(customersProvider.notifier).updateCustomer(newCustomer)
        : ref.read(customersProvider.notifier).addCustomer(newCustomer);
    saveFuture.catchError((Object e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save customer. Check your connection and retry.',
            ),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    });

    if (mounted) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      context.pop();
    }
  }

  String? _routeDropdownValue(List<DeliveryRoute> routes) {
    if (routes.isEmpty) return null;
    final id = _selectedRouteId;
    if (id != null && routes.any((r) => r.id == id)) return id;
    if (id != null) {
      final legacyId = RouteRefs.routeIdForRef(id, routes);
      if (legacyId != null) return legacyId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);

    if (_isEditMode && !_hydratedFromProvider) {
      final customersLoaded = ref.watch(customersLoadedProvider);
      final customer = ref
          .watch(customersProvider)
          .firstWhereOrNull((c) => c.id == widget.customerId);

      if (!customersLoaded && customer == null) {
        return const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (customersLoaded && customer == null) {
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: DeliveroAppBar(
            title: 'Partner',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('We could not find this customer.'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (customer != null && !_hydratePostFrameScheduled) {
        _hydratePostFrameScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hydratedFromProvider) return;
          final latest = ref
              .read(customersProvider)
              .firstWhereOrNull((c) => c.id == widget.customerId);
          if (latest != null) {
            setState(() {
              _populateFromCustomer(latest);
              _hydratedFromProvider = true;
            });
          } else {
            setState(() => _hydratePostFrameScheduled = false);
          }
        });
      }
      if (customer != null && !_hydratedFromProvider) {
        return const Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(child: CircularProgressIndicator()),
        );
      }
    }

    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            DeliveroSliverHeader(
              title: _isEditMode ? 'Edit customer' : 'Add customer',
              expandedHeight: 120,
              floating: true,
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isEditMode) ...[
                        _buildCustomerDetailsCard(routes),
                        const SizedBox(height: 28),
                      ],
                      _buildSectionHeader('Basics'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Business name',
                        _nameController,
                        Icons.business_rounded,
                        hint: 'e.g. Grand Plaza Hotel',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Owner or manager',
                        _ownerNameController,
                        Icons.person_pin_rounded,
                        hint: 'e.g. John Smith',
                        requiredField: false,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Phone',
                        _phoneController,
                        Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        hint: '+91 00000 00000',
                        requiredField: false,
                      ),
                      const SizedBox(height: 16),
                      AddressAutocompleteField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery address',
                          hintText: 'e.g. 12, MG Road, Bangalore',
                          prefixIcon: Icon(
                            Icons.location_on_rounded,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                      UseCurrentLocationButton(
                        addressController: _addressController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Discount (%)',
                        _discountController,
                        Icons.discount_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        hint: '0',
                        requiredField: false,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final d = double.tryParse(v.trim());
                          if (d == null) return 'Enter a number';
                          if (d < 0 || d > 100) return '0–100 only';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Delivery route'),
                      const SizedBox(height: 16),
                      _buildRouteDropdown(routes),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Products & prices'),
                      const SizedBox(height: 8),
                      Text(
                        'Select products, then set quantity and price if it differs from the list.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProductList(foodItems),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Status'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Active customer',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _isActive
                                        ? 'Daily orders will be recreated for this customer.'
                                        : 'Inactive — daily orders will not be recreated.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch.adaptive(
                              value: _isActive,
                              onChanged: (v) => setState(() => _isActive = v),
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton(
            onPressed: () {
              try {
                HapticFeedback.heavyImpact();
              } catch (_) {}
              _onSave();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: Text(
              _isEditMode ? 'Save changes' : 'Add customer',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onPrimary,
                letterSpacing: 1,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textLight,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCustomerDetailsCard(List<DeliveryRoute> routes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer details',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Quick view before editing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CustomerDetailTile(
                  label: 'Business',
                  value: _nameController.text.trim().isEmpty
                      ? '—'
                      : _nameController.text.trim(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CustomerDetailTile(
                  label: 'Owner',
                  value: _ownerNameController.text.trim().isEmpty
                      ? 'Not added'
                      : _ownerNameController.text.trim(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CustomerDetailTile(
                  label: 'Phone',
                  value: _phoneController.text.trim().isEmpty
                      ? 'Not added'
                      : _phoneController.text.trim(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    bool requiredField = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator:
          validator ??
          (requiredField
              ? (value) => (value == null || value.isEmpty)
                    ? 'This field is required'
                    : null
              : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildRouteDropdown(List<DeliveryRoute> routes) {
    final selectedId = _routeDropdownValue(routes);
    final selectedName = selectedId == null
        ? null
        : routes.firstWhereOrNull((r) => r.id == selectedId)?.name;

    Future<void> openPicker(FormFieldState<String> field) async {
      if (routes.isEmpty) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Choose a route',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: routes.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) {
                        final r = routes[i];
                        final isSelected = r.id == field.value;
                        return ListTile(
                          onTap: () => Navigator.pop(context, r.id),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(
                            r.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            r.area,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textLight,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (picked == null) return;
      setState(() => _selectedRouteId = picked);
      field.didChange(picked);
    }

    return FormField<String>(
      initialValue: selectedId,
      validator: (value) => value == null ? 'Choose a route' : null,
      builder: (field) {
        final showError = field.hasError;
        final displayText = selectedName ?? 'Tap to choose';

        return InkWell(
          onTap: routes.isEmpty ? null : () => openPicker(field),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Route',
              prefixIcon: const Icon(
                Icons.alt_route_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
              errorText: showError ? field.errorText : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selectedName == null
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductList(List<FoodItem> foodItems) {
    return Column(
      children: foodItems.map((item) {
        final isSelected = _selectedProducts.any((p) => p.id == item.id);
        if (!_quantityControllers.containsKey(item.id)) {
          _quantityControllers[item.id] = TextEditingController(text: '0');
        }
        if (!_priceControllers.containsKey(item.id)) {
          _priceControllers[item.id] = TextEditingController();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProducts.removeWhere((p) => p.id == item.id);
                        } else {
                          _selectedProducts.add(
                            CustomerProduct(
                              id: item.id,
                              name: item.name,
                              quantity: 0,
                            ),
                          );
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: isSelected,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textLight,
                                width: 1.5,
                              ),
                              fillColor: WidgetStateProperty.resolveWith((s) {
                                if (s.contains(WidgetState.selected)) {
                                  return AppColors.primary;
                                }
                                return null;
                              }),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProducts.add(
                                      CustomerProduct(
                                        id: item.id,
                                        name: item.name,
                                        quantity: 0,
                                      ),
                                    );
                                  } else {
                                    _selectedProducts.removeWhere(
                                      (p) => p.id == item.id,
                                    );
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    fontSize: 15,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'List ₹${item.price}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isSelected)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                                color: AppColors.textLight.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLighter.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'For this customer',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textLight,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Quantity each order',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Whole numbers only. List price for this item is ₹${item.price}.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _QtyStepButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: () {
                                      final c = _quantityControllers[item.id]!;
                                      final q =
                                          int.tryParse(c.text.trim()) ?? 0;
                                      final next = (q - 1).clamp(0, 999999);
                                      c.text = next.toString();
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _quantityControllers[item.id],
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        suffixText: 'units',
                                        suffixStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                        ),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QtyStepButton(
                                    icon: Icons.add_rounded,
                                    onPressed: () {
                                      final c = _quantityControllers[item.id]!;
                                      final q =
                                          int.tryParse(c.text.trim()) ?? 0;
                                      final next = (q + 1).clamp(0, 999999);
                                      c.text = next.toString();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Custom price (optional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Leave empty to use ₹${item.price}. Use decimals if needed (e.g. 42.50).',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _priceControllers[item.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  _DecimalPlacesInputFormatter(
                                    maxDecimalPlaces: 2,
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Amount in ₹',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                  hintText: '${item.price}',
                                  prefixText: '₹ ',
                                  prefixStyle: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomerDetailTile extends StatelessWidget {
  const _CustomerDetailTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepButton extends StatelessWidget {
  const _QtyStepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
      ),
    );
  }
}

/// Keeps at most one decimal point and [maxDecimalPlaces] digits after it.
class _DecimalPlacesInputFormatter extends TextInputFormatter {
  _DecimalPlacesInputFormatter({this.maxDecimalPlaces = 2});

  final int maxDecimalPlaces;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final parts = t.split('.');
    if (parts.length > 2) return oldValue;
    if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
      return oldValue;
    }
    return newValue;
  }
}

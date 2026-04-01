import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/customer.dart';
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
  String? _selectedRouteId;
  List<CustomerProduct> _selectedProducts = [];
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

  bool get _isEditMode => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();

    if (_isEditMode) {
      final customer = ref
          .read(customersProvider)
          .firstWhere((c) => c.id == widget.customerId);
      _nameController.text = customer.name;
      _ownerNameController.text = customer.ownerName ?? '';
      _phoneController.text = customer.phone;
      _addressController.text = customer.address;

      final routes = ref.read(routesProvider);
      final route = routes.firstWhereOrNull(
        (r) =>
            r.id == customer.assignedRoute || r.name == customer.assignedRoute,
      );
      _selectedRouteId = route?.id ?? customer.assignedRoute;

      _selectedProducts = List.from(customer.products ?? []);
      for (var p in _selectedProducts) {
        _quantityControllers[p.id] = TextEditingController(
          text: p.quantity.toString(),
        );
        if (p.customPrice != null) {
          _priceControllers[p.id] = TextEditingController(
            text: p.customPrice.toString(),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
    final routeName = selectedRoute?.name ?? _selectedRouteId;

    final factoryId = await ref.read(factoryIdProvider.future) ?? 'FAC_00001';
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
      address: _addressController.text,
      area: selectedRoute?.area ?? 'Central',
      isActive: true,
      assignedRoute: routeName,
      products: products,
      createdAt: _isEditMode
          ? (existingCustomer?.createdAt ?? DateTime.now())
          : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditMode) {
      ref.read(customersProvider.notifier).updateCustomer(newCustomer);
    } else {
      ref.read(customersProvider.notifier).addCustomer(newCustomer);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          DeliveroSliverHeader(
            title: _isEditMode ? 'Modify Partner' : 'Register Partner',
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
                    _buildSectionHeader('BASIC ENTITY INFORMATION'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Hotel/Commercial Name',
                      _nameController,
                      Icons.business_rounded,
                      hint: 'e.g. Grand Plaza Hotel',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Authorized Signatory',
                      _ownerNameController,
                      Icons.person_pin_rounded,
                      hint: 'e.g. John Smith',
                      requiredField: false,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Operational Contact',
                      _phoneController,
                      Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      hint: '+91 00000 00000',
                      requiredField: false,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Operational Address',
                      _addressController,
                      Icons.map_rounded,
                      maxLines: 3,
                      hint: 'Full physical location details...',
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('LOGISTICS ASSIGNMENT'),
                    const SizedBox(height: 16),
                    _buildRouteDropdown(routes),
                    const SizedBox(height: 32),
                    _buildSectionHeader('CONTRACTUAL INVENTORY'),
                    const SizedBox(height: 16),
                    _buildProductList(foodItems),
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
          onPressed: _onSave,
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
            _isEditMode ? 'UPDATE CONTRACT' : 'FINALIZE REGISTRATION',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
              fontSize: 14,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: requiredField
          ? (value) => (value == null || value.isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildRouteDropdown(List routes) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRouteId,
      items: routes.map<DropdownMenuItem<String>>((route) {
        return DropdownMenuItem<String>(
          value: route.id,
          child: Text(
            route.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedRouteId = value),
      decoration: const InputDecoration(
        labelText: 'Select Logistics Route',
        prefixIcon: Icon(
          Icons.alt_route_rounded,
          color: AppColors.textLight,
          size: 20,
        ),
      ),
      validator: (value) => value == null ? 'Please select a route' : null,
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

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.03)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
                      _selectedProducts.removeWhere((p) => p.id == item.id);
                    }
                  });
                },
              ),
              title: Text(
                item.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Catalog Price: ₹${item.price}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _quantityControllers[item.id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Default Quantity',
                            hintText: 'Units',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _priceControllers[item.id],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Contract Price',
                            hintText: 'Default ₹${item.price}',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

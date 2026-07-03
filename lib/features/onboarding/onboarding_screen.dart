import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/firebase_service.dart';
import '../../data/models/delivery_route.dart';
import '../../data/models/customer.dart';
import '../../data/models/food_item.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _kBusinessNameKey = 'onboarding_business_name';
  static const _kStepCount = 4;

  final _pageController = PageController();
  final _ownerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _routeNameController = TextEditingController();
  final _routeAreaController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();
  bool _profileLoaded = false;
  bool _didInitialJump = false;
  String _ownerName = '';
  String _businessName = '';
  int _currentStep = 0;
  bool _savingProfile = false;
  bool _savingRoute = false;
  bool _savingCustomer = false;
  bool _savingProduct = false;

  @override
  void initState() {
    super.initState();
    _ownerNameController.addListener(_onFormChanged);
    _businessNameController.addListener(_onFormChanged);
    _productNameController.addListener(_onFormChanged);
    _productPriceController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _ownerNameController.removeListener(_onFormChanged);
    _businessNameController.removeListener(_onFormChanged);
    _productNameController.removeListener(_onFormChanged);
    _productPriceController.removeListener(_onFormChanged);
    _pageController.dispose();
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _routeNameController.dispose();
    _routeAreaController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _productNameController.dispose();
    _productPriceController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> _saveInlineRoute() async {
    FocusScope.of(context).unfocus();
    final name = _routeNameController.text.trim();
    final area = _routeAreaController.text.trim();
    if (name.isEmpty || area.isEmpty) return false;

    // Skip if this exactly matches an existing route — keeps the inputs
    // populated for visual confirmation without creating duplicates when
    // the user comes back to this step and taps Next again.
    final existing = ref.read(routesProvider);
    final isDuplicate = existing.any(
      (r) =>
          r.name.trim().toLowerCase() == name.toLowerCase() &&
          r.area.trim().toLowerCase() == area.toLowerCase(),
    );
    if (isDuplicate) return true;

    setState(() => _savingRoute = true);
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final factoryId = await ref.read(factoryIdProvider.future);
    if (factoryId == null || factoryId.isEmpty) return false;
    final now = DateTime.now();
    final route = DeliveryRoute(
      id: const Uuid().v4(),
      factoryId: factoryId,
      name: name,
      area: area,
      description: '',
      isActive: true,
      estimatedDeliveryTime: 30,
      maxOrders: 10,
      currentOrders: 0,
      createdAt: now,
      updatedAt: now,
    );
    ref.read(routesProvider.notifier).addRoute(route);

    if (!mounted) return true;
    setState(() => _savingRoute = false);
    return true;
  }

  Future<bool> _saveInlineCustomer() async {
    FocusScope.of(context).unfocus();
    final name = _customerNameController.text.trim();
    final phone = _customerPhoneController.text.trim();
    final address = _customerAddressController.text.trim();
    if (name.isEmpty) return false;

    // Skip if name (and phone, if provided) match an existing customer.
    final existing = ref.read(customersProvider);
    final isDuplicate = existing.any((c) {
      final sameName = c.name.trim().toLowerCase() == name.toLowerCase();
      if (phone.isEmpty) return sameName;
      return sameName && c.phone.trim() == phone;
    });
    if (isDuplicate) return true;

    setState(() => _savingCustomer = true);
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final factoryId = await ref.read(factoryIdProvider.future);
    if (factoryId == null || factoryId.isEmpty) return false;
    final now = DateTime.now();
    final customer = Customer(
      id: const Uuid().v4(),
      factoryId: factoryId,
      name: name,
      email: '',
      phone: phone,
      address: address,
      area: '',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    ref.read(customersProvider.notifier).addCustomer(customer);

    if (!mounted) return true;
    setState(() => _savingCustomer = false);
    return true;
  }

  Future<bool> _saveInlineProduct() async {
    FocusScope.of(context).unfocus();
    final name = _productNameController.text.trim();
    final priceText = _productPriceController.text.trim();
    if (name.isEmpty || priceText.isEmpty) return false;

    final price = double.tryParse(priceText);
    if (price == null || price < 0) {
      _showSnack('Enter a valid price (e.g. 25.00).');
      return false;
    }

    // Skip if name + price match an existing product.
    final existing = ref.read(foodItemsProvider);
    final isDuplicate = existing.any(
      (f) =>
          f.name.trim().toLowerCase() == name.toLowerCase() && f.price == price,
    );
    if (isDuplicate) return true;

    setState(() => _savingProduct = true);
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final factoryId = await ref.read(factoryIdProvider.future);
    if (factoryId == null || factoryId.isEmpty) return false;
    final now = DateTime.now();
    final item = FoodItem(
      id: const Uuid().v4(),
      factoryId: factoryId,
      name: name,
      price: price,
      createdAt: now,
      updatedAt: now,
    );
    ref.read(foodItemsProvider.notifier).addFoodItem(item);

    if (!mounted) return true;
    setState(() => _savingProduct = false);
    return true;
  }

  Future<void> _ensureProfileLoaded() async {
    if (_profileLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cachedBusiness = (prefs.getString(_kBusinessNameKey) ?? '').trim();
    final cachedOwner = (ref.read(authProvider).user?.name ?? '').trim();
    if (!mounted) return;
    setState(() {
      _profileLoaded = true;
      _businessName = cachedBusiness;
      _businessNameController.text = cachedBusiness;
      _ownerName = cachedOwner;
      _ownerNameController.text = cachedOwner;
    });
  }

  int _firstIncompleteIndex({
    required bool profileDone,
    required bool routesDone,
    required bool customersDone,
    required bool productsDone,
  }) {
    if (!profileDone) return 0;
    if (!routesDone) return 1;
    if (!customersDone) return 2;
    if (!productsDone) return 3;
    return _kStepCount - 1;
  }

  Future<bool> _saveProfile() async {
    FocusScope.of(context).unfocus();
    final ownerNext = _ownerNameController.text.trim();
    final businessNext = _businessNameController.text.trim();

    if (ownerNext.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return false;
    }
    if (businessNext.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your business name')),
      );
      return false;
    }

    setState(() => _savingProfile = true);
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      await ref.read(authProvider.notifier).updateOwnerName(ownerNext);
    } catch (_) {
      // Best-effort: surfacing a failure here would block onboarding flow.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBusinessNameKey, businessNext);

    try {
      final factoryId = ref.read(factoryIdProvider).asData?.value;
      if (factoryId != null &&
          factoryId.trim().isNotEmpty &&
          FirebaseService.isInitialized) {
        await FirebaseService.firestore
            .collection('factories')
            .doc(factoryId)
            .set({
              'name': businessNext,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (_) {
      // Best-effort: local persistence already completed.
    }

    if (!mounted) return false;
    setState(() {
      _ownerName = ownerNext;
      _businessName = businessNext;
      _savingProfile = false;
    });
    return true;
  }

  Future<void> _finishOnboarding() async {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    await ref.read(authProvider.notifier).completeOnboarding();
    if (!mounted) return;

    final ownerName = ref.read(authProvider).user?.name.trim() ?? '';
    final businessName = _businessName.trim();

    await _showSetupCompleteDialog(
      ownerName: ownerName,
      businessName: businessName,
    );
    if (!mounted) return;
    if (context.mounted) context.go('/owner');
  }

  Future<void> _showSetupCompleteDialog({
    required String ownerName,
    required String businessName,
  }) async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => _SetupCompleteDialog(
        ownerName: ownerName,
        businessName: businessName,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _jumpTo(int index) {
    final safe = index.clamp(0, _kStepCount - 1);
    _pageController.animateToPage(
      safe,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentStep = safe);
  }

  void _goBack() {
    if (_currentStep == 0) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    _jumpTo(_currentStep - 1);
  }

  Future<void> _goNext({
    required bool routesDone,
    required bool productsDone,
    required bool allRequiredDone,
  }) async {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    switch (_currentStep) {
      case 0:
        final saved = await _saveProfile();
        if (!saved || !mounted) return;
        _jumpTo(1);
        return;
      case 1:
        final hasName = _routeNameController.text.trim().isNotEmpty;
        final hasArea = _routeAreaController.text.trim().isNotEmpty;
        final hasFormData = hasName && hasArea;
        final hasPartialData = (hasName || hasArea) && !hasFormData;
        final hasExistingRoutes = ref.read(routesProvider).isNotEmpty;

        if (hasFormData) {
          final saved = await _saveInlineRoute();
          if (!saved || !mounted) return;
          _jumpTo(2);
          return;
        }

        if (hasPartialData) {
          _showSnack('Enter both a route name and area to add it.');
          return;
        }

        if (!hasExistingRoutes) {
          _showSnack('Enter a route name and area above, then tap Next.');
          return;
        }

        _jumpTo(2);
        return;
      case 2:
        // Customers step is optional. If user entered a name, save it.
        if (_customerNameController.text.trim().isNotEmpty) {
          await _saveInlineCustomer();
          if (!mounted) return;
        }
        _jumpTo(3);
        return;
      case 3:
        final hasName = _productNameController.text.trim().isNotEmpty;
        final hasPrice = _productPriceController.text.trim().isNotEmpty;
        final hasFormData = hasName && hasPrice;
        final hasPartialData = (hasName || hasPrice) && !hasFormData;
        final hasExistingProducts = ref.read(foodItemsProvider).isNotEmpty;

        if (hasFormData) {
          final saved = await _saveInlineProduct();
          if (!saved || !mounted) return;
          await _finishOnboarding();
          return;
        }

        if (hasPartialData) {
          _showSnack('Enter both a product name and price to add it.');
          return;
        }

        if (!hasExistingProducts) {
          _showSnack('Enter a product name and price above, then tap Launch.');
          return;
        }

        await _finishOnboarding();
        return;
    }
  }

  void _showSnack(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  void _selectStep(int index, int firstIncomplete) {
    if (index > firstIncomplete) return;
    if (index == _currentStep) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    _jumpTo(index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureProfileLoaded(),
      );
    }

    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final customers = ref.watch(customersProvider);

    final profileDone =
        _ownerName.trim().isNotEmpty && _businessName.trim().isNotEmpty;
    final routesDone = routes.isNotEmpty;
    final customersDone = customers.isNotEmpty;
    final productsDone = foodItems.isNotEmpty;
    final allRequiredDone = profileDone && routesDone && productsDone;

    final firstIncomplete = _firstIncompleteIndex(
      profileDone: profileDone,
      routesDone: routesDone,
      customersDone: customersDone,
      productsDone: productsDone,
    );

    if (!_didInitialJump && _profileLoaded) {
      _didInitialJump = true;
      if (_currentStep < firstIncomplete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _pageController.jumpToPage(firstIncomplete);
          setState(() => _currentStep = firstIncomplete);
        });
      }
    }

    final stepStatuses = <bool>[
      profileDone,
      routesDone,
      customersDone,
      productsDone,
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Business setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1} of $_kStepCount',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _StepperHeader(
              labels: const ['Profile', 'Routes', 'Customers', 'Products'],
              statuses: stepStatuses,
              currentIndex: _currentStep,
              firstIncomplete: firstIncomplete,
              onTap: (i) => _selectStep(i, firstIncomplete),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _BusinessStepPage(
                    ownerController: _ownerNameController,
                    businessController: _businessNameController,
                    isCompleted: profileDone,
                    saving: _savingProfile,
                  ),
                  _RoutesStepPage(
                    nameController: _routeNameController,
                    areaController: _routeAreaController,
                    saving: _savingRoute,
                  ),
                  _CustomersStepPage(
                    nameController: _customerNameController,
                    phoneController: _customerPhoneController,
                    addressController: _customerAddressController,
                    saving: _savingCustomer,
                  ),
                  _ProductsStepPage(
                    nameController: _productNameController,
                    priceController: _productPriceController,
                    saving: _savingProduct,
                  ),
                ],
              ),
            ),
            _BottomNav(
              currentStep: _currentStep,
              isLastStep: _currentStep == _kStepCount - 1,
              allRequiredDone:
                  allRequiredDone ||
                  (profileDone &&
                      routesDone &&
                      _productNameController.text.trim().isNotEmpty &&
                      _productPriceController.text.trim().isNotEmpty),
              saving:
                  _savingProfile ||
                  _savingRoute ||
                  _savingCustomer ||
                  _savingProduct,
              onBack: _goBack,
              onContinue: () => _goNext(
                routesDone: routesDone,
                productsDone: productsDone,
                allRequiredDone: allRequiredDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================  Stepper header  =====================

class _StepperHeader extends StatelessWidget {
  final List<String> labels;
  final List<bool> statuses;
  final int currentIndex;
  final int firstIncomplete;
  final ValueChanged<int> onTap;

  const _StepperHeader({
    required this.labels,
    required this.statuses,
    required this.currentIndex,
    required this.firstIncomplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = labels.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(count * 2 - 1, (i) {
                if (i.isOdd) {
                  final leftIndex = i ~/ 2;
                  final reached = statuses[leftIndex];
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: reached ? AppColors.success : AppColors.border,
                      ),
                    ),
                  );
                }
                final stepIndex = i ~/ 2;
                final isCompleted = statuses[stepIndex];
                final isActive = stepIndex == currentIndex;
                final isLocked = stepIndex > firstIncomplete;
                return _StepDot(
                  index: stepIndex,
                  isCompleted: isCompleted,
                  isActive: isActive,
                  isLocked: isLocked,
                  onTap: () => onTap(stepIndex),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(count, (i) {
              final isActive = i == currentIndex;
              final isCompleted = statuses[i];
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                    color: isActive
                        ? AppColors.primary
                        : (isCompleted
                              ? AppColors.success
                              : AppColors.textLight),
                    letterSpacing: 0.2,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool isCompleted;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;

  const _StepDot({
    required this.index,
    required this.isCompleted,
    required this.isActive,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color textColor;
    if (isCompleted) {
      fill = AppColors.success;
      textColor = Colors.white;
    } else if (isActive) {
      fill = AppColors.primary;
      textColor = Colors.white;
    } else {
      fill = AppColors.surface;
      textColor = AppColors.textLight;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isLocked ? null : onTap,
      child: SizedBox(
        width: 40,
        height: 36,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: isActive ? 30 : 26,
            height: isActive ? 30 : 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: isCompleted || isActive ? fill : AppColors.border,
                width: 1.4,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: isActive ? 13 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// =====================  Step pages  =====================

class _StepScaffold extends StatelessWidget {
  final Widget child;
  const _StepScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: child,
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final bool isCompleted;
  final bool isRequired;

  const _StepHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.isCompleted,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const Spacer(),
            _StatusChip(isCompleted: isCompleted, isRequired: isRequired),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BusinessStepPage extends StatelessWidget {
  final TextEditingController ownerController;
  final TextEditingController businessController;
  final bool isCompleted;
  final bool saving;

  const _BusinessStepPage({
    required this.ownerController,
    required this.businessController,
    required this.isCompleted,
    required this.saving,
  });

  InputDecoration _decoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Tell us about you',
            description:
                "Your name and business name appear across your dashboard and reports.",
            icon: Icons.storefront_rounded,
            accent: AppColors.primary,
            isCompleted: isCompleted,
            isRequired: true,
          ),
          const SizedBox(height: 26),
          const Text(
            'Your name',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ownerController,
            enabled: !saving,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(
              hint: 'e.g. Anita Rao',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Business name',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: businessController,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(
              hint: 'e.g. Acme Foods',
              icon: Icons.store_rounded,
            ),
          ),
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.info_outline_rounded,
            text:
                'You can update both anytime from settings. The business name will be saved to your factory profile.',
          ),
        ],
      ),
    );
  }
}

class _RoutesStepPage extends ConsumerWidget {
  final TextEditingController nameController;
  final TextEditingController areaController;
  final bool saving;

  const _RoutesStepPage({
    required this.nameController,
    required this.areaController,
    required this.saving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = ref.watch(routesProvider).isNotEmpty;

    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Set up your routes',
            description:
                'Add at least one delivery route. Give it a name and the area it covers, then tap Next.',
            icon: Icons.route_rounded,
            accent: AppColors.primary,
            isCompleted: isCompleted,
            isRequired: true,
          ),
          const SizedBox(height: 22),
          const _FormFieldLabel(label: 'Route name'),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            enabled: !saving,
            textInputAction: TextInputAction.next,
            decoration: _formDecoration(
              hint: 'e.g. City Center Route',
              icon: Icons.label_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),
          const _FormFieldLabel(label: 'Area covered'),
          const SizedBox(height: 8),
          TextField(
            controller: areaController,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            decoration: _formDecoration(
              hint: 'e.g. Downtown',
              icon: Icons.place_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  final String label;
  const _FormFieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

InputDecoration _formDecoration({
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
    ),
  );
}

class _CustomersStepPage extends ConsumerWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final bool saving;

  const _CustomersStepPage({
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.saving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = ref.watch(customersProvider).isNotEmpty;

    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Add your customers',
            description:
                'Add a customer to get started, or skip this step and tap Next.',
            icon: Icons.people_alt_rounded,
            accent: AppColors.info,
            isCompleted: isCompleted,
            isRequired: false,
          ),
          const SizedBox(height: 22),
          const _FormFieldLabel(label: 'Customer name'),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            enabled: !saving,
            textInputAction: TextInputAction.next,
            decoration: _formDecoration(
              hint: 'e.g. Sunrise Cafe',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),
          const _FormFieldLabel(label: 'Phone'),
          const SizedBox(height: 8),
          TextField(
            controller: phoneController,
            enabled: !saving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _formDecoration(
              hint: 'e.g. +91 98765 43210',
              icon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 14),
          const _FormFieldLabel(label: 'Address'),
          const SizedBox(height: 8),
          TextField(
            controller: addressController,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            decoration: _formDecoration(
              hint: 'e.g. 12 Market Road, Kochi',
              icon: Icons.place_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductsStepPage extends ConsumerWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final bool saving;

  const _ProductsStepPage({
    required this.nameController,
    required this.priceController,
    required this.saving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = ref.watch(foodItemsProvider).isNotEmpty;

    return _StepScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Add your products',
            description:
                'Add the items you sell. You can update prices and add more later.',
            icon: Icons.inventory_2_rounded,
            accent: AppColors.warning,
            isCompleted: isCompleted,
            isRequired: true,
          ),
          const SizedBox(height: 22),
          const _FormFieldLabel(label: 'Product name'),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            enabled: !saving,
            textInputAction: TextInputAction.next,
            decoration: _formDecoration(
              hint: 'e.g. Fresh Bread',
              icon: Icons.label_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),
          const _FormFieldLabel(label: 'Price'),
          const SizedBox(height: 8),
          TextField(
            controller: priceController,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: _formDecoration(
              hint: 'e.g. 25.00',
              icon: Icons.attach_money_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isCompleted;
  final bool isRequired;

  const _StatusChip({required this.isCompleted, required this.isRequired});

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final String label;
    if (isCompleted) {
      fg = AppColors.success;
      bg = AppColors.successLighter;
      label = 'Done';
    } else if (isRequired) {
      fg = AppColors.error;
      bg = AppColors.errorLighter;
      label = 'Required';
    } else {
      fg = AppColors.textSecondary;
      bg = AppColors.backgroundSecondary;
      label = 'Optional';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.infoLighter,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================  Bottom navigation  =====================

class _BottomNav extends StatelessWidget {
  final int currentStep;
  final bool isLastStep;
  final bool allRequiredDone;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _BottomNav({
    required this.currentStep,
    required this.isLastStep,
    required this.allRequiredDone,
    required this.saving,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final showBack = currentStep > 0;
    final continueEnabled = !saving;

    String label;
    IconData icon;
    if (isLastStep) {
      label = saving ? 'Saving…' : 'Launch dashboard';
      icon = Icons.rocket_launch_rounded;
    } else if (currentStep == 0) {
      label = saving ? 'Saving…' : 'Save & next';
      icon = Icons.arrow_forward_rounded;
    } else {
      label = saving ? 'Saving…' : 'Next';
      icon = Icons.arrow_forward_rounded;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              if (showBack) ...[
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _PrimaryButton(
                  label: label,
                  icon: icon,
                  enabled: continueEnabled,
                  loading: saving,
                  isSuccess: isLastStep && allRequiredDone,
                  onTap: continueEnabled ? onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final bool isSuccess;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.isSuccess,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = enabled
        ? (isSuccess
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.success, Color(0xFF047857)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientEnd,
                  ],
                ))
        : null;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient,
          color: enabled ? null : AppColors.border,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (isSuccess ? AppColors.success : AppColors.primary)
                        .withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: enabled ? Colors.white : AppColors.textSecondary,
                    size: 18,
                  ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: enabled ? Colors.white : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupCompleteDialog extends StatefulWidget {
  final String ownerName;
  final String businessName;
  final VoidCallback onDismiss;

  const _SetupCompleteDialog({
    required this.ownerName,
    required this.businessName,
    required this.onDismiss,
  });

  @override
  State<_SetupCompleteDialog> createState() => _SetupCompleteDialogState();
}

class _SetupCompleteDialogState extends State<_SetupCompleteDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _checkController;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _badgeScale;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _cardScale = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _cardOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _badgeScale = CurvedAnimation(
      parent: _checkController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );
    _checkProgress = CurvedAnimation(
      parent: _checkController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _entryController.forward();
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _checkController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerFirstName = widget.ownerName.split(' ').first.trim();
    final hasName = ownerFirstName.isNotEmpty;
    final hasBusiness = widget.businessName.isNotEmpty;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Opacity(
          opacity: _cardOpacity.value,
          child: Transform.scale(
            scale: 0.85 + (_cardScale.value * 0.15),
            child: child,
          ),
        );
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _checkController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: 0.6 + (_badgeScale.value * 0.4),
                    child: _SuccessBadge(progress: _checkProgress.value),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                hasName
                    ? "You're all set, $ownerFirstName!"
                    : "You're all set!",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  hasBusiness
                      ? '${widget.businessName} is ready to roll. Let\'s open your dashboard and start delivering.'
                      : 'Your workspace is ready. Let\'s open your dashboard and start delivering.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _ReadyHighlights(),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Open dashboard',
                  icon: Icons.dashboard_rounded,
                  enabled: true,
                  loading: false,
                  isSuccess: true,
                  onTap: widget.onDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  final double progress;
  const _SuccessBadge({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.success, Color(0xFF047857)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(44, 44),
          painter: _CheckmarkPainter(progress: progress),
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final start = Offset(size.width * 0.18, size.height * 0.52);
    final mid = Offset(size.width * 0.42, size.height * 0.74);
    final end = Offset(size.width * 0.82, size.height * 0.30);

    final firstLeg = (mid - start).distance;
    final secondLeg = (end - mid).distance;
    final total = firstLeg + secondLeg;
    final drawn = total * progress.clamp(0.0, 1.0);

    final path = Path()..moveTo(start.dx, start.dy);
    if (drawn <= firstLeg) {
      final t = firstLeg == 0 ? 0.0 : drawn / firstLeg;
      final p = Offset.lerp(start, mid, t)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(mid.dx, mid.dy);
      final remaining = drawn - firstLeg;
      final t = secondLeg == 0 ? 0.0 : remaining / secondLeg;
      final p = Offset.lerp(mid, end, t)!;
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ReadyHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: const [
          _ReadyHighlightRow(
            icon: Icons.alt_route_rounded,
            label: 'Routes mapped',
          ),
          SizedBox(height: 8),
          _ReadyHighlightRow(
            icon: Icons.people_alt_rounded,
            label: 'Customers added',
          ),
          SizedBox(height: 8),
          _ReadyHighlightRow(
            icon: Icons.restaurant_menu_rounded,
            label: 'Menu loaded',
          ),
        ],
      ),
    );
  }
}

class _ReadyHighlightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ReadyHighlightRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.successLighter,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

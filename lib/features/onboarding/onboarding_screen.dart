import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/firebase_service.dart';

class SetupStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final String actionLabel;
  final String importance;
  final String? route;

  SetupStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isCompleted,
    required this.actionLabel,
    required this.route,
    required this.importance,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _kBusinessNameKey = 'onboarding_business_name';

  final _businessNameController = TextEditingController();
  bool _businessLoaded = false;
  String _businessName = '';
  int _currentStep = 0;

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _ensureBusinessLoaded() async {
    if (_businessLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString(_kBusinessNameKey) ?? '').trim();
    if (!mounted) return;
    setState(() {
      _businessLoaded = true;
      _businessName = name;
      _businessNameController.text = name;
    });
  }

  int _firstIncompleteIndex({
    required bool businessDone,
    required bool routesDone,
    required bool customersDone,
    required bool productsDone,
  }) {
    if (!businessDone) return 0;
    if (!routesDone) return 1;
    if (!customersDone) return 2;
    if (!productsDone) return 3;
    return 3;
  }

  Future<void> _saveBusinessName() async {
    FocusScope.of(context).unfocus();
    final next = _businessNameController.text.trim();
    if (next.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your business name')),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBusinessNameKey, next);

    // Persist into Firestore factory document as well (best-effort).
    try {
      final factoryId = ref.read(factoryIdProvider).asData?.value;
      if (factoryId != null &&
          factoryId.trim().isNotEmpty &&
          FirebaseService.isInitialized) {
        await FirebaseService.firestore
            .collection('factories')
            .doc(factoryId)
            .set({
              'name': next,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (_) {
      // Best-effort: local persistence already completed.
    }

    if (!mounted) return;
    setState(() => _businessName = next);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Business name saved')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_businessLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureBusinessLoaded(),
      );
    }

    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final customers = ref.watch(customersProvider);

    final businessDone = _businessName.trim().isNotEmpty;
    final routesDone = routes.isNotEmpty;
    final customersDone = customers.isNotEmpty;
    final productsDone = foodItems.isNotEmpty;

    final allDone = businessDone && routesDone && customersDone && productsDone;

    final requiredDone = businessDone && routesDone && productsDone;
    final requiredLeft = requiredDone
        ? 0
        : (businessDone ? 0 : 1) +
              (routesDone ? 0 : 1) +
              (productsDone ? 0 : 1);

    final firstIncomplete = _firstIncompleteIndex(
      businessDone: businessDone,
      routesDone: routesDone,
      customersDone: customersDone,
      productsDone: productsDone,
    );

    if (_currentStep < firstIncomplete) {
      // Prevent user from staying on a previous step that is already complete.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentStep = firstIncomplete);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Business setup',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (requiredLeft > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: _buildBadge('$requiredLeft required')),
            ),
        ],
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (i) {
          // No skipping ahead: only allow navigating to completed steps or the first incomplete step.
          if (i <= firstIncomplete) {
            setState(() => _currentStep = i);
          }
        },
        controlsBuilder: (context, details) {
          final isLast = details.currentStep == 3;
          final canFinish = allDone;
          final canContinue = details.currentStep < 3;

          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isLast
                        ? (canFinish
                              ? () async {
                                  try {
                                    HapticFeedback.mediumImpact();
                                  } catch (_) {}
                                  await ref
                                      .read(authProvider.notifier)
                                      .completeOnboarding();
                                  if (context.mounted) context.go('/owner');
                                }
                              : null)
                        : (canContinue ? details.onStepContinue : null),
                    style: FilledButton.styleFrom(
                      backgroundColor: isLast
                          ? (canFinish ? AppColors.success : AppColors.border)
                          : AppColors.primary,
                      disabledBackgroundColor: AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isLast
                          ? (canFinish
                                ? 'Finish setup'
                                : 'Complete steps to finish')
                          : 'Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isLast && !canFinish
                            ? AppColors.textSecondary
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.currentStep == 0
                      ? null
                      : details.onStepCancel,
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
        onStepContinue: () async {
          switch (_currentStep) {
            case 0:
              await _saveBusinessName();
              if (!mounted) return;
              if (_businessName.trim().isNotEmpty) {
                setState(() => _currentStep = 1);
              }
              return;
            case 1:
              try {
                HapticFeedback.selectionClick();
              } catch (_) {}
              context.push('/owner/routes');
              return;
            case 2:
              try {
                HapticFeedback.selectionClick();
              } catch (_) {}
              context.push('/owner/customers');
              return;
            case 3:
              try {
                HapticFeedback.selectionClick();
              } catch (_) {}
              context.push('/owner/food-items');
              return;
          }
        },
        onStepCancel: () {
          if (_currentStep == 0) return;
          setState(() => _currentStep -= 1);
        },
        steps: [
          Step(
            title: const Text('Business details'),
            subtitle: businessDone
                ? Text(_businessName)
                : const Text('Required'),
            isActive: _currentStep == 0,
            state: businessDone ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add your business name. This will be saved to your factory profile.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _businessNameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveBusinessName(),
                  decoration: InputDecoration(
                    hintText: 'Business name',
                    prefixIcon: const Icon(Icons.store_rounded, size: 20),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Add route'),
            subtitle: routesDone ? const Text('Done') : const Text('Required'),
            isActive: _currentStep == 1,
            state: routesDone ? StepState.complete : StepState.indexed,
            content: const Text(
              'Create at least one delivery route to organize operations.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          Step(
            title: const Text('Add customer'),
            subtitle: customersDone
                ? const Text('Done')
                : const Text('Optional'),
            isActive: _currentStep == 2,
            state: customersDone ? StepState.complete : StepState.indexed,
            content: const Text(
              'Add customers and assign them to routes.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          Step(
            title: const Text('Add products'),
            subtitle: productsDone
                ? const Text('Done')
                : const Text('Required'),
            isActive: _currentStep == 3,
            state: productsDone ? StepState.complete : StepState.indexed,
            content: const Text(
              'Add the products/items you sell so orders can be created.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: allDone
                  ? () async {
                      try {
                        HapticFeedback.mediumImpact();
                      } catch (_) {}
                      await ref
                          .read(authProvider.notifier)
                          .completeOnboarding();
                      if (context.mounted) context.go('/owner');
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: allDone ? AppColors.success : AppColors.border,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                allDone ? 'Launch dashboard' : 'Complete all steps to continue',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: allDone ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

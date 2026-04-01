import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_sliver_header.dart';

class SetupStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final String actionLabel;
  final String route;
  final String importance;

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
  String? _expandedStepId = 'routes';
  bool _autoMarked = false;

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final customers = ref.watch(customersProvider);
    final orders = ref.watch(ordersProvider);

    final steps = [
      SetupStep(
        id: 'routes',
        title: 'Setup Delivery Routes',
        description:
            'Create routes and assign drivers for deliveries. This is essential for organizing your delivery operations.',
        icon: Icons.route_rounded,
        isCompleted: routes.isNotEmpty,
        actionLabel: 'Add Routes',
        route: '/owner/routes',
        importance: 'critical',
      ),
      SetupStep(
        id: 'products',
        title: 'Add Food Items',
        description:
            'Add your menu items with prices. These are the products your customers will order.',
        icon: Icons.restaurant_menu_rounded,
        isCompleted: foodItems.isNotEmpty,
        actionLabel: 'Add Products',
        route: '/owner/food-items',
        importance: 'critical',
      ),
      SetupStep(
        id: 'customers',
        title: 'Add Customers',
        description:
            'Add your customer details, assign them to routes, and set their regular orders.',
        icon: Icons.people_rounded,
        isCompleted: customers.isNotEmpty,
        actionLabel: 'Add Customers',
        route: '/owner/customers',
        importance: 'important',
      ),
      SetupStep(
        id: 'orders',
        title: 'Create Orders',
        description:
            'Start creating orders for your customers. Daily orders or one-time orders.',
        icon: Icons.receipt_long_rounded,
        isCompleted: orders.isNotEmpty,
        actionLabel: 'Create Order',
        route: '/owner/orders',
        importance: 'important',
      ),
    ];

    final completedCount = steps.where((s) => s.isCompleted).length;
    final progress = completedCount / steps.length;
    final criticalStepsLeft = steps
        .where((s) => s.importance == 'critical' && !s.isCompleted)
        .length;

    if (criticalStepsLeft == 0 && !_autoMarked) {
      _autoMarked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(appStartupProvider.notifier).markOnboardingSeen();
        if (!mounted) return;
        context.go('/owner');
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Setup Guide',
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(appStartupProvider.notifier).markOnboardingSeen(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildProgressCard(completedCount, steps.length, progress),
            if (criticalStepsLeft > 0) ...[
              const SizedBox(height: 24),
              _buildAlertBox(criticalStepsLeft),
            ],
            const SizedBox(height: 32),
            const Text(
              'Setup Steps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map(
              (entry) => _buildStepCard(entry.value, entry.key + 1),
            ),
            const SizedBox(height: 40),
            if (criticalStepsLeft == 0)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => ref
                      .read(appStartupProvider.notifier)
                      .markOnboardingSeen(),
                  child: const Text('Go to Dashboard'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Welcome! Let's Get Started",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          "Complete these steps to start managing your delivery business",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildProgressCard(int completed, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Setup Progress',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.backgroundSecondary,
            color: AppColors.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed of $total steps completed',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBox(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLighter.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Complete $count required step(s) to start taking orders',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(SetupStep step, int index) {
    final isExpanded = _expandedStepId == step.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () =>
                setState(() => _expandedStepId = isExpanded ? null : step.id),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? AppColors.success
                    : AppColors.backgroundSecondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: step.isCompleted
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        index.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            title: Text(
              step.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: step.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                color: step.isCompleted
                    ? AppColors.textLight
                    : AppColors.textPrimary,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push(step.route),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        step.isCompleted ? 'View/Edit' : step.actionLabel,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: step.isCompleted
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

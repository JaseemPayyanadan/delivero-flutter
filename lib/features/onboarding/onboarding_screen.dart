import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool _autoMarked = false;

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final customers = ref.watch(customersProvider);
    final orders = ref.watch(ordersProvider);

    final steps = [
      SetupStep(
        id: 'routes',
        title: 'Define Delivery Routes',
        description:
            'Organize your operations by creating delivery routes. Assign drivers and areas to streamline your logistics.',
        icon: Icons.map_rounded,
        isCompleted: routes.isNotEmpty,
        actionLabel: 'Add First Route',
        route: '/owner/routes',
        importance: 'critical',
      ),
      SetupStep(
        id: 'products',
        title: 'Build Your Menu',
        description:
            'Add the products and food items you sell. Set prices and categories to make ordering easy for your customers.',
        icon: Icons.restaurant_menu_rounded,
        isCompleted: foodItems.isNotEmpty,
        actionLabel: 'Add Menu Items',
        route: '/owner/food-items',
        importance: 'critical',
      ),
      SetupStep(
        id: 'customers',
        title: 'Onboard Customers',
        description:
            'Add your regular customers and link them to their routes. You can even set recurring daily orders.',
        icon: Icons.people_alt_rounded,
        isCompleted: customers.isNotEmpty,
        actionLabel: 'Add Customers',
        route: '/owner/customers',
        importance: 'important',
      ),
      SetupStep(
        id: 'orders',
        title: 'Process First Order',
        description:
            'Everything is ready! Create your first delivery order and start managing your business in real-time.',
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

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(completedCount, steps.length, progress),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Setup Checklist',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      if (criticalStepsLeft > 0)
                        _buildBadge('$criticalStepsLeft Required'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Follow these steps to get your factory up and running.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...steps.asMap().entries.map(
                    (entry) => _buildStepCard(entry.value, entry.key + 1),
                  ),
                  const SizedBox(height: 40),
                  _buildFooterAction(criticalStepsLeft == 0),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(int completed, int total, double progress) {
    return SliverAppBar(
      expandedHeight: 280,
      collapsedHeight: 100,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: const SizedBox.shrink(),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: TextButton(
            onPressed: () =>
                ref.read(authProvider.notifier).completeOnboarding(),
            child: const Text(
              'Skip Guide',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative background
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 240,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to Delivero!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s set up your business workspace.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildHeaderProgress(completed, total, progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderProgress(int completed, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Setup Progress',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed of $total steps completed',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  Widget _buildFooterAction(bool isFinished) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: isFinished
          ? FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(authProvider.notifier).completeOnboarding();
                context.go('/owner');
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Launch Dashboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: () =>
                  ref.read(authProvider.notifier).completeOnboarding(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'I\'ll do this later',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

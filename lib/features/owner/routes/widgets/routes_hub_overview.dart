import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Summary KPIs for the routes & drivers hub.
class RoutesHubOverviewCard extends StatelessWidget {
  final int routesCount;
  final int driversOnDuty;
  final int routesWithoutDriver;

  const RoutesHubOverviewCard({
    super.key,
    required this.routesCount,
    required this.driversOnDuty,
    required this.routesWithoutDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _HubStat(
                icon: Icons.alt_route_rounded,
                iconColor: AppColors.primary,
                value: routesCount,
                label: 'Routes',
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _HubStat(
                icon: Icons.how_to_reg_rounded,
                iconColor: AppColors.success,
                value: driversOnDuty,
                label: 'On duty',
              ),
            ),
            _verticalRule(),
            Expanded(
              child: _HubStat(
                icon: Icons.assignment_ind_rounded,
                iconColor: routesWithoutDriver > 0
                    ? AppColors.warning
                    : AppColors.textLight,
                value: routesWithoutDriver,
                label: 'No driver',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalRule() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 1,
      height: 40,
      color: AppColors.border,
    );
  }
}

class _HubStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;

  const _HubStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.appTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// iOS-style two-segment control for Routes / Drivers.
class RoutesHubSegmentedControl extends StatelessWidget {
  final TabController controller;

  const RoutesHubSegmentedControl({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _segment(
                    context,
                    index: 0,
                    icon: Icons.alt_route_rounded,
                    label: 'Routes',
                  ),
                ),
                Expanded(
                  child: _segment(
                    context,
                    index: 1,
                    icon: Icons.groups_rounded,
                    label: 'Drivers',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = controller.index == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (controller.index != index) {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            controller.animateTo(index);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: -0.15,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

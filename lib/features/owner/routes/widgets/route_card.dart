import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/delivery_route.dart';
import '../../../../data/models/driver.dart';

class RouteCard extends StatelessWidget {
  final DeliveryRoute route;
  final String driverName;
  final bool hasDriver;
  final String? vehicleTypeLabel;
  final VehicleType? vehicleType;
  final VoidCallback onTap;
  final VoidCallback onAssign;
  final Widget trailingMenu;

  const RouteCard({
    super.key,
    required this.route,
    required this.driverName,
    required this.hasDriver,
    this.vehicleTypeLabel,
    this.vehicleType,
    required this.onTap,
    required this.onAssign,
    required this.trailingMenu,
  });

  String _vehicleAsset(VehicleType type) {
    switch (type) {
      case VehicleType.bike:
        return 'assets/images/scooty.png';
      case VehicleType.scooter:
        return 'assets/images/scooter.webp';
      case VehicleType.auto:
        return 'assets/images/auto.png';
      case VehicleType.van:
        return 'assets/images/scooter.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = route.isActive
        ? AppColors.success
        : AppColors.textDisabled;
    final statusBg = statusColor.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  route.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.appTextStyles.appBarTitle
                                      .copyWith(
                                        fontSize: 17,
                                        letterSpacing: -0.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  route.isActive ? 'Active' : 'Inactive',
                                  style: context.appTextStyles.caption.copyWith(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.6,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              if (route.area.trim().isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    route.area.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.appTextStyles.caption
                                        .copyWith(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          height: 1.0,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    trailingMenu,
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: hasDriver
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.errorLighter.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        hasDriver
                            ? Icons.person_pin_circle_rounded
                            : Icons.person_off_rounded,
                        size: 16,
                        color: hasDriver ? AppColors.primary : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (hasDriver && vehicleType != null) ...[
                      Container(
                        width: 30,
                        height: 30,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Image.asset(
                          _vehicleAsset(vehicleType!),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vehicleTypeLabel ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: hasDriver
                              ? AppColors.textPrimary
                              : AppColors.error,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (!hasDriver) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: onAssign,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Assign'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'order_detail_surfaces.dart';

/// Standalone customer card: avatar + name, phone | address columns, and a
/// "View customer" link. All contact rows are tappable when a handler is set.
class OrderDetailCustomerCard extends StatelessWidget {
  final String name;
  final String phone;
  final String address;
  final String routeLabel;
  final VoidCallback? onCall;
  final VoidCallback? onOpenAddress;
  final VoidCallback? onViewCustomer;

  const OrderDetailCustomerCard({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    required this.routeLabel,
    this.onCall,
    this.onOpenAddress,
    this.onViewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Customer' : name.trim();
    final initial = displayName.characters.first.toUpperCase();
    final hasPhone = phone.trim().isNotEmpty;
    final hasAddress = address.trim().isNotEmpty;
    final captionMuted = context.appTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
    );

    return OrderDetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLighter,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer', style: captionMuted),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (routeLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    routeLabel.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasPhone || hasAddress) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasPhone)
                    Expanded(
                      child: _ContactCell(
                        icon: Icons.phone_rounded,
                        label: phone.trim(),
                        onTap: onCall,
                        semanticsLabel: 'Call ${phone.trim()}',
                      ),
                    ),
                  if (hasPhone && hasAddress)
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppColors.divider,
                    ),
                  if (hasAddress)
                    Expanded(
                      flex: hasPhone ? 2 : 1,
                      child: _ContactCell(
                        icon: Icons.location_on_rounded,
                        label: address.trim(),
                        onTap: onOpenAddress,
                        semanticsLabel: 'Open ${address.trim()} in maps',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (onViewCustomer != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onViewCustomer,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View customer',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const _ContactCell({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Semantics(button: true, label: semanticsLabel, child: row),
        ),
      ),
    );
  }
}

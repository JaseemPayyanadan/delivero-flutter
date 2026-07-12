import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Reference details: the full contact fields plus account facts that don't
/// need to be above the fold.
class CustomerContactCard extends StatelessWidget {
  final String phone;
  final String email;
  final String address;
  final String ownerName;
  final String routeLabel;
  final double discountPercentage;
  final String customerSince;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;
  final VoidCallback? onOpenAddress;

  const CustomerContactCard({
    super.key,
    required this.phone,
    required this.email,
    required this.address,
    required this.ownerName,
    required this.routeLabel,
    required this.discountPercentage,
    required this.customerSince,
    this.onCall,
    this.onEmail,
    this.onOpenAddress,
  });

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DetailSectionHeader(title: 'Contact & info'),
          const SizedBox(height: 8),
          if (phone.isNotEmpty)
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: phone,
              onTap: onCall,
            ),
          if (email.isNotEmpty)
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
              onTap: onEmail,
            ),
          if (address.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'Address',
              value: address,
              onTap: onOpenAddress,
            ),
          if (ownerName.isNotEmpty)
            _InfoRow(
              icon: Icons.person_rounded,
              label: 'Owner / Manager',
              value: ownerName,
            ),
          if (routeLabel.isNotEmpty)
            _InfoRow(
              icon: Icons.alt_route_rounded,
              label: 'Route',
              value: routeLabel,
            ),
          if (discountPercentage > 0)
            _InfoRow(
              icon: Icons.discount_rounded,
              label: 'Discount',
              value:
                  '${discountPercentage.toStringAsFixed(0)}% off all orders',
            ),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Customer since',
            value: customerSince,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap != null ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onTap != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.textLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

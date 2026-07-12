import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Card that overlaps the gradient header: ring-status avatar, name, a single
/// route-and-status meta line, and a call button on the right.
class CustomerIdentityCard extends StatelessWidget {
  final String name;
  final String initials;
  final String routeLabel;
  final bool isActive;
  final String phone;
  final String ownerName;
  final String address;
  final VoidCallback? onCall;
  final VoidCallback? onOpenAddress;

  const CustomerIdentityCard({
    super.key,
    required this.name,
    required this.initials,
    required this.routeLabel,
    required this.isActive,
    required this.phone,
    required this.ownerName,
    required this.address,
    this.onCall,
    this.onOpenAddress,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;
    final hasOwner = ownerName.trim().isNotEmpty;
    final hasAddress = address.trim().isNotEmpty;
    final statusColor = isActive ? AppColors.success : AppColors.textLight;

    final meta = <String>[
      if (routeLabel.trim().isNotEmpty) routeLabel.trim(),
      isActive ? 'Active' : 'Inactive',
    ].join(' · ');

    return DetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RingAvatar(initials: initials, ringColor: statusColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    if (hasOwner) ...[
                      const SizedBox(height: 3),
                      Text(
                        ownerName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPhone) ...[
                const SizedBox(width: 12),
                _CallButton(
                  onTap: onCall,
                  semanticsLabel: 'Call ${phone.trim()}',
                ),
              ],
            ],
          ),
          if (hasAddress) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            _AddressRow(
              address: address.trim(),
              onTap: onOpenAddress,
            ),
          ],
        ],
      ),
    );
  }
}

/// The delivery address, tappable straight into maps.
class _AddressRow extends StatelessWidget {
  final String address;
  final VoidCallback? onTap;

  const _AddressRow({required this.address, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.location_on_rounded,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
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
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: 8, top: 1),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textLight,
            ),
          ),
      ],
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: 'Open $address in maps',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Initials avatar wrapped in a ring that carries the active/inactive state,
/// so the card needs no separate status pill.
class _RingAvatar extends StatelessWidget {
  final String initials;
  final Color ringColor;

  const _RingAvatar({required this.initials, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primaryLighter,
          shape: BoxShape.circle,
        ),
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String semanticsLabel;

  const _CallButton({required this.semanticsLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: AppColors.successLighter.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.call_rounded,
              size: 20,
              color: AppColors.success,
            ),
          ),
        ),
      ),
    );
  }
}

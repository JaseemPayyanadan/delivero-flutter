import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Card that overlaps the gradient header: initials avatar, name, route and
/// active pill, plus the Call / Email / Navigate contact columns.
class CustomerIdentityCard extends StatelessWidget {
  final String name;
  final String initials;
  final String routeLabel;
  final bool isActive;
  final String phone;
  final String email;
  final String address;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;
  final VoidCallback? onNavigate;

  const CustomerIdentityCard({
    super.key,
    required this.name,
    required this.initials,
    required this.routeLabel,
    required this.isActive,
    required this.phone,
    required this.email,
    required this.address,
    this.onCall,
    this.onEmail,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;
    final hasEmail = email.trim().isNotEmpty;
    final hasAddress = address.trim().isNotEmpty;
    final hasContacts = hasPhone || hasEmail || hasAddress;

    return DetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLighter,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
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
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(active: isActive),
                        if (routeLabel.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.alt_route_rounded,
                                  size: 13,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    routeLabel.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasContacts) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasPhone)
                  Expanded(
                    child: _ContactColumn(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      color: AppColors.success,
                      onTap: onCall,
                      semanticsLabel: 'Call ${phone.trim()}',
                    ),
                  ),
                if (hasEmail)
                  Expanded(
                    child: _ContactColumn(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      color: AppColors.info,
                      onTap: onEmail,
                      semanticsLabel: 'Email ${email.trim()}',
                    ),
                  ),
                if (hasAddress)
                  Expanded(
                    child: _ContactColumn(
                      icon: Icons.near_me_rounded,
                      label: 'Navigate',
                      color: AppColors.primary,
                      onTap: onNavigate,
                      semanticsLabel: 'Open ${address.trim()} in maps',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppColors.successLighter.withValues(alpha: 0.7)
        : AppColors.backgroundSecondary;
    final fg = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: fg,
              fontSize: 10,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String semanticsLabel;

  const _ContactColumn({
    required this.icon,
    required this.label,
    required this.color,
    required this.semanticsLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
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

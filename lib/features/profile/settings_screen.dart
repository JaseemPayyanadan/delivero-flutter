import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/delivero_sliver_header.dart';
import '../../data/models/user.dart';
import '../../data/models/driver.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isAvailable = true;
  bool _notifyOnAssignment = true;
  bool _vibrateOnStatus = false;
  String? _prefsKey;
  bool _prefsLoaded = false;
  bool _availabilitySynced = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs(null);
  }

  Future<void> _loadPrefs(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = key == null ? 'settings' : 'settings_$key';
    final available = prefs.getBool('${prefix}_available');
    final notify = prefs.getBool('${prefix}_notify');
    final vibrate = prefs.getBool('${prefix}_vibrate');
    if (!mounted) return;
    setState(() {
      if (available != null) _isAvailable = available;
      if (notify != null) _notifyOnAssignment = notify;
      if (vibrate != null) _vibrateOnStatus = vibrate;
      _prefsKey = key;
      _prefsLoaded = true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _prefsKey == null ? 'settings' : 'settings_$_prefsKey';
    await prefs.setBool('${prefix}_$key', value);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final drivers = ref.watch(driversProvider);
    final driversLoaded = ref.watch(driversLoadedProvider);
    final isDelivery = user?.role == UserRole.delivery;
    final subtitle = user == null
        ? 'Your account and settings'
        : (isDelivery
              ? 'Your account, when you are on duty, and alerts'
              : 'Your account and how the app behaves');

    final userKey = user?.id;
    if (!_prefsLoaded || _prefsKey != userKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadPrefs(userKey);
      });
    }

    Driver? driver;
    if (isDelivery && user != null) {
      final driverId = user.linkedEntityId;
      if (driverId != null && driverId.isNotEmpty) {
        for (final d in drivers) {
          if (d.id == driverId) {
            driver = d;
            break;
          }
        }
      }
    }

    if (isDelivery && !_availabilitySynced && driver != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isAvailable = driver!.isActive;
          _availabilitySynced = true;
        });
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Profile',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeroCard(
                    user: user,
                    subtitle: subtitle,
                    driver: driver,
                    isDelivery: isDelivery,
                  ),
                  const SizedBox(height: 20),
                  _SettingsGroupCard(
                    title: 'Preferences',
                    child: Column(
                      children: [
                        _ProfileSwitchRow(
                          title: isDelivery ? 'On duty' : 'Open for business',
                          description: isDelivery
                              ? 'Turn off when you are not taking deliveries'
                              : 'Turn off when you are closed',
                          value: _isAvailable,
                          onChanged:
                              isDelivery &&
                                  (!driversLoaded ||
                                      (user?.linkedEntityId != null &&
                                          driver == null))
                              ? null
                              : (val) {
                                  setState(() => _isAvailable = val);
                                  _savePref('available', val);
                                  if (isDelivery && driver != null) {
                                    final updated = driver.copyWith(
                                      isActive: val,
                                      updatedAt: DateTime.now(),
                                    );
                                    ref
                                        .read(driversProvider.notifier)
                                        .updateDriver(updated);
                                  }
                                },
                          icon: Icons.bolt_rounded,
                          iconColor: AppColors.warning,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _ProfileSwitchRow(
                          title: 'Notifications',
                          description: isDelivery
                              ? 'Alert me when I get a new route'
                              : 'Alert me when orders change',
                          value: _notifyOnAssignment,
                          onChanged: (val) {
                            setState(() => _notifyOnAssignment = val);
                            _savePref('notify', val);
                          },
                          icon: Icons.notifications_active_rounded,
                          iconColor: AppColors.primary,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _ProfileSwitchRow(
                          title: 'Vibration',
                          description: 'Haptic feedback for important updates',
                          value: _vibrateOnStatus,
                          onChanged: (val) {
                            setState(() => _vibrateOnStatus = val);
                            _savePref('vibrate', val);
                          },
                          icon: Icons.vibration_rounded,
                          iconColor: AppColors.info,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroupCard(
                    title: 'Support',
                    child: Column(
                      children: [
                        _ProfileNavRow(
                          title: 'Help',
                          description: 'Walkthrough and tips',
                          icon: Icons.help_center_rounded,
                          iconColor: AppColors.primary,
                          onTap: () => context.go('/onboarding'),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _ProfileNavRow(
                          title: 'Licenses & privacy',
                          description: 'Open-source notices and legal',
                          icon: Icons.gavel_rounded,
                          iconColor: AppColors.textSecondary,
                          onTap: () => showLicensePage(context: context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        try {
                          HapticFeedback.heavyImpact();
                        } catch (_) {}
                        _showLogoutDialog();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        'Sign out',
                        style: context.appTextStyles.buttonLabel.copyWith(
                          fontSize: 15,
                          letterSpacing: 0.2,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to keep using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Stay signed in',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Sign out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsGroupCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.appTextStyles.sectionHeader.copyWith(
                      fontSize: 15,
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          child,
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final User? user;
  final String subtitle;
  final Driver? driver;
  final bool isDelivery;

  const _ProfileHeroCard({
    required this.user,
    required this.subtitle,
    required this.driver,
    required this.isDelivery,
  });

  String _vehicleTypeLabel(VehicleType type) {
    final n = type.name;
    return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
  }

  String _initials(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 108,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLighter.withValues(alpha: 0.85),
                    AppColors.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: user == null
                ? _ProfileHeroSkeleton()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(
                                color: AppColors.border,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 14,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryLighter,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initials(user!.name),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account',
                                  style: context.appTextStyles.caption
                                      .copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.15,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user!.name.trim().isEmpty
                                      ? '—'
                                      : user!.name.trim(),
                                  style: context.appTextStyles.sliverTitle
                                      .copyWith(
                                    fontSize: 21,
                                    height: 1.12,
                                  ),
                                ),
                                if (user!.role == UserRole.delivery) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.info,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Driver',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.person_pin_circle_outlined,
                              size: 18,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subtitle,
                              style: context.appTextStyles.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isDelivery && driver != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLighter,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vehicle',
                                      style: context.appTextStyles.caption
                                          .copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_vehicleTypeLabel(driver!.vehicleType)} · On file',
                                      style: context.appTextStyles.sectionHeader
                                          .copyWith(
                                        fontSize: 14,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: driver!.isActive
                                      ? AppColors.successLighter
                                      : AppColors.backgroundTertiary,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: driver!.isActive
                                        ? AppColors.success
                                            .withValues(alpha: 0.22)
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  driver!.isActive ? 'Available' : 'Off duty',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.35,
                                    color: driver!.isActive
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Contact',
                        style: context.appTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.15,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _ProfileContactLine(
                              icon: Icons.phone_iphone_rounded,
                              label: 'Phone',
                              text: user!.phone.trim().isEmpty
                                  ? '—'
                                  : user!.phone.trim(),
                            ),
                            if (user!.factoryId != null &&
                                user!.factoryId!.trim().isNotEmpty) ...[
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                              _ProfileContactLine(
                                icon: Icons.factory_outlined,
                                label: 'Workspace',
                                text: user!.factoryId!.trim(),
                              ),
                            ],
                          ],
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

class _ProfileHeroSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 10,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 20,
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 10,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ],
    );
  }
}

class _ProfileContactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _ProfileContactLine({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.appTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: context.appTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
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

class _ProfileNavRow extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ProfileNavRow({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.appTextStyles.sectionHeader.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: context.appTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final Color iconColor;

  const _ProfileSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: disabled ? AppColors.textLight : iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.appTextStyles.sectionHeader.copyWith(
                    fontSize: 15,
                    color: disabled ? AppColors.textLight : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: context.appTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.92,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.success,
              activeTrackColor: AppColors.success.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/order_settings_provider.dart';
import '../../app/providers.dart';
import '../../core/orders/business_day.dart';
import '../../core/services/order_day_reset_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/delivero_button.dart';
import '../../core/widgets/delivero_gradient_header.dart';
import '../../core/widgets/delivero_sliver_header.dart';
import '../../core/widgets/delivero_status_chip.dart';
import '../../data/models/user.dart';
import '../../data/models/driver.dart';
import 'widgets/edit_profile_sheet.dart';
import '../../core/widgets/detail_surfaces.dart';
import '../../core/widgets/destructive_confirm_dialog.dart';
import 'widgets/profile_identity_card.dart';

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
    final factory = ref.watch(factoryProvider).asData?.value;
    final companyName = factory?.name;
    final companyAddress = factory?.address;

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
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: DeliveroGradientHeader(
              title: 'Profile',
              subtitle: isDelivery ? 'Driver account' : 'Owner account',
              onBack: Navigator.of(context).canPop()
                  ? () => context.pop()
                  : null,
              horizontalPadding: 20,
              bannerHeight: 104,
              overlap: 36,
              overlapChild: ProfileIdentityCard(
                name: user?.name ?? '',
                phone: user?.phone ?? '',
                initials: _profileInitials(user?.name ?? ''),
                isDelivery: isDelivery,
                loading: user == null,
                onEdit: user == null
                    ? null
                    : () => showEditProfileSheet(
                        context: context,
                        ref: ref,
                        name: user.name,
                        phone: user.phone,
                        isDelivery: isDelivery,
                        companyName: companyName,
                        companyAddress: companyAddress,
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileDetailsSection(
                    user: user,
                    driver: driver,
                    isDelivery: isDelivery,
                    companyName: companyName,
                    companyAddress: companyAddress,
                  ),
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
                          onChanged: (val) async {
                            setState(() => _notifyOnAssignment = val);
                            await _savePref('notify', val);
                            if (!isDelivery && user != null) {
                              await OrderDayResetNotificationService.instance
                                  .syncForOwner(
                                    user: user,
                                    rolloverHour: ref.read(
                                      orderRolloverHourProvider,
                                    ),
                                  );
                            }
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
                  if (!isDelivery) ...[
                    const SizedBox(height: 16),
                    _SettingsGroupCard(
                      title: 'Orders',
                      child: Column(
                        children: [
                          _ProfileNavRow(
                            title: 'Order settings',
                            description:
                                'Daily order recreation, day-reset time, and manual generation',
                            icon: Icons.tune_rounded,
                            iconColor: AppColors.success,
                            onTap: () => context.push('/owner/order-settings'),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDestructiveConfirmDialog(
      context: context,
      title: 'Sign out?',
      message: 'You will need to sign in again with your phone number to keep '
          'using the app.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !mounted) return;
    ref.read(authProvider.notifier).logout();
  }
}

class OrderSettingsScreen extends ConsumerStatefulWidget {
  const OrderSettingsScreen({super.key});

  @override
  ConsumerState<OrderSettingsScreen> createState() =>
      _OrderSettingsScreenState();
}

class _OrderSettingsScreenState extends ConsumerState<OrderSettingsScreen> {
  bool _isGeneratingDailyOrders = false;
  String? _syncedFactory;

  @override
  Widget build(BuildContext context) {
    final rolloverHour = ref.watch(orderRolloverHourProvider);
    final autoRecreateDaily = ref.watch(autoRecreateDailyOrdersProvider);

    final factoryId = ref.watch(authProvider).user?.factoryId;
    if (factoryId != null &&
        factoryId.isNotEmpty &&
        _syncedFactory != factoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncedFactory = factoryId);
        ref.read(orderRolloverHourProvider.notifier).syncForFactory(factoryId);
        ref
            .read(autoRecreateDailyOrdersProvider.notifier)
            .syncForFactory(factoryId);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Order settings',
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: _SettingsGroupCard(
                title: 'Daily orders',
                child: Column(
                  children: [
                    _ProfileSwitchRow(
                      title: 'Auto-recreate daily orders',
                      description:
                          'When on, daily orders (even if not delivered) are recreated automatically at the time below. Edits sync into the next day\'s pending order.',
                      value: autoRecreateDaily,
                      onChanged: (val) async {
                        await ref
                            .read(autoRecreateDailyOrdersProvider.notifier)
                            .setEnabled(val);
                      },
                      icon: Icons.autorenew_rounded,
                      iconColor: AppColors.success,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _ProfileTimeRow(
                      title: 'New order day starts at',
                      description:
                          'Before this time, orders count as the previous day. After this time, daily orders are recreated and earlier orders are locked.',
                      timeLabel: formatOrderRolloverLabel(rolloverHour),
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.secondary,
                      onTap: () => _pickOrderResetTime(rolloverHour),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _ProfileGenerateOrdersRow(
                      isLoading: _isGeneratingDailyOrders,
                      onPressed: _isGeneratingDailyOrders
                          ? null
                          : () => _generateDailyOrdersNow(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateDailyOrdersNow() async {
    final factoryId = ref.read(authProvider).user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;

    setState(() => _isGeneratingDailyOrders = true);
    try {
      final result = await ref
          .read(ordersProvider.notifier)
          .runManualDailyOrderGeneration(factoryId);
      if (!mounted) return;

      final message = switch (result.createdCount) {
        0 =>
          'No new daily orders needed — today\'s orders are already in place',
        1 => '1 daily order generated for today',
        _ => '${result.createdCount} daily orders generated for today',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: result.createdCount > 0
              ? AppColors.success
              : AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingDailyOrders = false);
    }
  }

  Future<void> _pickOrderResetTime(int currentHour) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: 0),
      helpText: 'When does the new order day start?',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    await ref
        .read(orderRolloverHourProvider.notifier)
        .setRolloverHour(picked.hour);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order day resets at ${formatOrderRolloverLabel(picked.hour)}. Delivered daily orders will be recreated at that time.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailSectionHeader(title: title),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

String _profileInitials(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
  return (first + second).toUpperCase();
}

/// Company (owner), vehicle (delivery), and plan (owner) detail cards shown
/// below the header.
class _ProfileDetailsSection extends StatelessWidget {
  final User? user;
  final Driver? driver;
  final bool isDelivery;
  final String? companyName;
  final String? companyAddress;

  const _ProfileDetailsSection({
    required this.user,
    required this.driver,
    required this.isDelivery,
    required this.companyName,
    required this.companyAddress,
  });

  String _vehicleTypeLabel(VehicleType type) {
    final n = type.name;
    return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
  }

  String _planName(SubscriptionPlan plan) {
    return switch (plan) {
      SubscriptionPlan.free => 'Free',
      SubscriptionPlan.pro => 'Pro',
    };
  }

  String _planDescription(SubscriptionPlan plan) {
    return switch (plan) {
      SubscriptionPlan.free =>
        isDelivery
            ? 'Using the workspace free plan'
            : 'Basic workspace features are active',
      SubscriptionPlan.pro =>
        isDelivery
            ? 'Using the workspace pro plan'
            : 'Advanced workspace features are active',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    final rows = <Widget>[];

    if (!isDelivery && companyName != null && companyName!.trim().isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _ProfileInfoTile(
            icon: Icons.storefront_rounded,
            label: 'Company',
            title: companyName!.trim(),
            subtitle:
                (companyAddress != null && companyAddress!.trim().isNotEmpty)
                ? companyAddress!.trim()
                : 'Your workspace',
            accentColor: AppColors.primary,
          ),
        ),
      );
    }

    if (isDelivery && driver != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                      style: context.appTextStyles.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_vehicleTypeLabel(driver!.vehicleType)} · On file',
                      style: context.appTextStyles.sectionHeader.copyWith(
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              DeliveroStatusChip(
                label: driver!.isActive ? 'AVAILABLE' : 'OFF DUTY',
                tone: driver!.isActive
                    ? StatusChipTone.success
                    : StatusChipTone.neutral,
              ),
            ],
          ),
        ),
      );
    }

    if (!isDelivery) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _ProfileInfoTile(
            icon: Icons.workspace_premium_rounded,
            label: 'Plan',
            title: _planName(user!.plan),
            subtitle: _planDescription(user!.plan),
            accentColor: user!.plan == SubscriptionPlan.pro
                ? AppColors.warning
                : AppColors.primary,
          ),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroupCard(
          title: isDelivery ? 'Vehicle' : 'Business',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 22),
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
                  letterSpacing: 0.4,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: context.appTextStyles.sectionHeader.copyWith(
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.appTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _ProfileGenerateOrdersRow extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ProfileGenerateOrdersRow({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                child: const Icon(
                  Icons.playlist_add_check_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate daily orders',
                      style: context.appTextStyles.sectionHeader.copyWith(
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fill any missing daily orders up to today from your most recent run — without waiting for the scheduled time.',
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
            ],
          ),
          const SizedBox(height: 12),
          DeliveroButton(
            onPressed: onPressed,
            isLoading: isLoading,
            icon: Icons.auto_fix_high_rounded,
            label: isLoading ? 'Generating…' : 'Generate now',
            backgroundColor: AppColors.primary,
            borderRadius: 999,
          ),
        ],
      ),
    );
  }
}

class _ProfileTimeRow extends StatelessWidget {
  final String title;
  final String description;
  final String timeLabel;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ProfileTimeRow({
    required this.title,
    required this.description,
    required this.timeLabel,
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        timeLabel,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
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

import 'package:flutter/material.dart';
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

    final userKey = user?.email;
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
        physics: const BouncingScrollPhysics(),
        slivers: [
          DeliveroSliverHeader(
            title: 'Profile',
            subtitle: subtitle,
            expandedHeight: 140,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(user),
                  const SizedBox(height: 28),
                  _SectionCard(
                    title: 'Preferences',
                    child: Column(
                      children: [
                        _buildSwitchTileRow(
                          title: isDelivery ? 'On duty' : 'Open for business',
                          description: isDelivery
                              ? 'Turn this off when you are not taking deliveries'
                              : 'Turn this off when you are closed',
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
                                    final d = driver;
                                    final updated = Driver(
                                      id: d.id,
                                      factoryId: d.factoryId,
                                      name: d.name,
                                      phone: d.phone,
                                      vehicleType: d.vehicleType,
                                      isActive: val,
                                      currentRoute: d.currentRoute,
                                      createdAt: d.createdAt,
                                      updatedAt: DateTime.now(),
                                    );
                                    ref
                                        .read(driversProvider.notifier)
                                        .updateDriver(updated);
                                  }
                                },
                          icon: Icons.online_prediction_rounded,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _buildSwitchTileRow(
                          title: 'Notifications',
                          description: isDelivery
                              ? 'Let me know when I get a new route'
                              : 'Let me know when something changes with orders',
                          value: _notifyOnAssignment,
                          onChanged: (val) {
                            setState(() => _notifyOnAssignment = val);
                            _savePref('notify', val);
                          },
                          icon: Icons.notifications_active_rounded,
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _buildSwitchTileRow(
                          title: 'Vibration',
                          description: 'Buzz the phone for important updates',
                          value: _vibrateOnStatus,
                          onChanged: (val) {
                            setState(() => _vibrateOnStatus = val);
                            _savePref('vibrate', val);
                          },
                          icon: Icons.vibration_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SectionCard(
                    title: 'Support',
                    child: Column(
                      children: [
                        _buildSettingsOptionRow(
                          title: 'Help',
                          description: 'Walkthrough and tips',
                          icon: Icons.help_center_rounded,
                          onTap: () => context.go('/onboarding'),
                        ),
                        const Divider(height: 1, color: AppColors.divider),
                        _buildSettingsOptionRow(
                          title: 'Licenses & privacy',
                          description: 'Open-source licenses and legal info',
                          icon: Icons.gavel_rounded,
                          onTap: () => showLicensePage(context: context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        'Sign out',
                        style: context.appTextStyles.buttonLabel.copyWith(
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.name.trim().isNotEmpty
                    ? user.name.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: context.appTextStyles.appBarTitle),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.role.name.toUpperCase(),
                    style: context.appTextStyles.caption.copyWith(
                      color: AppColors.textLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildContactRow(Icons.alternate_email_rounded, user.email),
                if (user.phone != null && user.phone!.trim().isNotEmpty)
                  _buildContactRow(Icons.phone_iphone_rounded, user.phone!),
                if (user.factoryId != null && user.factoryId!.trim().isNotEmpty)
                  _buildContactRow(
                    Icons.factory_rounded,
                    user.factoryId!.trim(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text(
            text,
            style: context.appTextStyles.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOptionRow({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: context.appTextStyles.sectionHeader),
      subtitle: Text(
        description,
        style: context.appTextStyles.caption.copyWith(
          fontSize: 12,
          color: AppColors.textLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textLight,
        size: 20,
      ),
    );
  }

  Widget _buildSwitchTileRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    return SwitchListTile.adaptive(
      title: Text(title, style: context.appTextStyles.sectionHeader),
      subtitle: Text(
        description,
        style: context.appTextStyles.caption.copyWith(
          fontSize: 12,
          color: AppColors.textLight,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.success,
      activeTrackColor: AppColors.success.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.textLight, size: 20),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

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
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(
              title.toUpperCase(),
              style: context.appTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
                letterSpacing: 1.2,
                height: 1.0,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
        ],
      ),
    );
  }
}

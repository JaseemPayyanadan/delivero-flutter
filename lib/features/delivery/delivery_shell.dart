import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/order_settings_provider.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard/delivery_dashboard_screen.dart';
import 'order_status_list_screen.dart';
import '../profile/settings_screen.dart';
import 'delivery_nav_provider.dart';

class DeliveryShell extends ConsumerStatefulWidget {
  const DeliveryShell({super.key});

  @override
  ConsumerState<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends ConsumerState<DeliveryShell> {
  String? _syncedRolloverFactory;

  @override
  Widget build(BuildContext context) {
    final factoryId = ref.watch(authProvider).user?.factoryId;
    if (factoryId != null &&
        factoryId.isNotEmpty &&
        _syncedRolloverFactory != factoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncedRolloverFactory = factoryId);
        ref.read(orderRolloverHourProvider.notifier).syncForFactory(factoryId);
      });
    }

    final selectedIndex = ref.watch(deliveryNavIndexProvider);
    final screens = const [
      DeliveryDashboardScreen(),
      OrderStatusListScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 52,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.primaryLighter,
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: selected ? AppColors.primary : AppColors.textLight,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  fontSize: 10,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected ? AppColors.primary : AppColors.textLight,
                  size: 20,
                );
              }),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  if (selectedIndex != index) {
                    try {
                      HapticFeedback.selectionClick();
                    } catch (_) {}
                    ref
                        .read(deliveryNavIndexProvider.notifier)
                        .setIndex(index);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.house),
                    selectedIcon: Icon(CupertinoIcons.house_fill),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.bag),
                    selectedIcon: Icon(CupertinoIcons.bag_fill),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.person),
                    selectedIcon: Icon(CupertinoIcons.person_fill),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

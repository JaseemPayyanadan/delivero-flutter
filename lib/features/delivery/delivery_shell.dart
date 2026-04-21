import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'dashboard/delivery_dashboard_screen.dart';
import 'order_status_list_screen.dart';
import '../profile/settings_screen.dart';
import 'delivery_nav_provider.dart';

class DeliveryShell extends ConsumerWidget {
  const DeliveryShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(deliveryNavIndexProvider);
    final screens = const [
      DeliveryDashboardScreen(),
      OrderStatusListScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          decoration: const BoxDecoration(color: AppColors.surface),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 52,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  fontSize: 10,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
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
                onDestinationSelected: (index) =>
                    ref.read(deliveryNavIndexProvider.notifier).setIndex(index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.speedometer),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.list_bullet),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.settings),
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

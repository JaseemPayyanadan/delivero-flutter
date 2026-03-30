import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';

import 'dashboard/delivery_dashboard_screen.dart';
import 'order_status_list_screen.dart';
import '../profile/settings_screen.dart';

class DeliveryShell extends ConsumerStatefulWidget {
  const DeliveryShell({super.key});

  @override
  ConsumerState<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends ConsumerState<DeliveryShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DeliveryDashboardScreen(),
    const OrderStatusListScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DELIVERO',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.6),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(CupertinoIcons.square_arrow_right),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.car_detailed),
                    selectedIcon: Icon(
                      CupertinoIcons.car_detailed,
                      color: AppColors.primary,
                    ),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.list_bullet),
                    selectedIcon: Icon(
                      CupertinoIcons.list_bullet,
                      color: AppColors.primary,
                    ),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.gear),
                    selectedIcon: Icon(
                      CupertinoIcons.gear_solid,
                      color: AppColors.primary,
                    ),
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

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'dashboard/owner_dashboard_screen.dart';
import 'customers/customer_list_screen.dart';
import 'orders/order_list_screen.dart';
import 'reports/reports_screen.dart';
import '../profile/settings_screen.dart';

class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({super.key});

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const OwnerDashboardScreen(),
    const OrderListScreen(),
    const CustomerListScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
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
                    icon: Icon(CupertinoIcons.house),
                    selectedIcon: Icon(
                      CupertinoIcons.house_fill,
                      color: AppColors.primary,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.doc_text),
                    selectedIcon: Icon(
                      CupertinoIcons.doc_text_fill,
                      color: AppColors.primary,
                    ),
                    label: 'Order',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.person_2),
                    selectedIcon: Icon(
                      CupertinoIcons.person_2_fill,
                      color: AppColors.primary,
                    ),
                    label: 'Customer',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.chart_bar),
                    selectedIcon: Icon(
                      CupertinoIcons.chart_bar_fill,
                      color: AppColors.primary,
                    ),
                    label: 'Insights',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.gear),
                    selectedIcon: Icon(
                      CupertinoIcons.gear_solid,
                      color: AppColors.primary,
                    ),
                    label: 'Profile',
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

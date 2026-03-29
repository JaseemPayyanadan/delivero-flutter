import 'package:flutter/material.dart';
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              label: 'Order',
            ),
            NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(
                Icons.business_center_rounded,
                color: AppColors.primary,
              ),
              label: 'Customer',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(
                Icons.analytics_rounded,
                color: AppColors.primary,
              ),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(
                Icons.manage_accounts_rounded,
                color: AppColors.primary,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

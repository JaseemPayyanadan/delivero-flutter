import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../app/providers.dart';
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
    final orders = ref.watch(ordersProvider);
    final showOrderFab = _selectedIndex == 1 && orders.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: !showOrderFab
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/owner/orders/create'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 10,
              child: const Icon(Icons.add_rounded, size: 26),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 52,
              backgroundColor: Colors.white,
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
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.house),
                    selectedIcon: Icon(CupertinoIcons.house_fill),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.bag),
                    selectedIcon: Icon(CupertinoIcons.bag_fill),
                    label: 'Order',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.person_2),
                    selectedIcon: Icon(CupertinoIcons.person_2_fill),
                    label: 'Customer',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.chart_bar),
                    selectedIcon: Icon(CupertinoIcons.chart_bar_fill),
                    label: 'Insights',
                  ),
                  NavigationDestination(
                    icon: Icon(CupertinoIcons.settings),
                    selectedIcon: Icon(CupertinoIcons.settings_solid),
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

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pill_bottom_nav_bar.dart';
import '../../app/order_settings_provider.dart';
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
  String? _syncedOrderSettingsFactory;

  final List<Widget> _screens = [
    const OwnerDashboardScreen(),
    const OrderListScreen(),
    const CustomerListScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final factoryId = ref.watch(authProvider).user?.factoryId;
    if (factoryId != null &&
        factoryId.isNotEmpty &&
        _syncedOrderSettingsFactory != factoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncedOrderSettingsFactory = factoryId);
        ref.read(orderRolloverHourProvider.notifier).syncForFactory(factoryId);
      });
    }

    final orders = ref.watch(ordersProvider);
    // Hide the "+" FAB when the Orders view is showing an empty state — those
    // states carry their own Generate/Add/Create actions.
    final ordersViewEmpty = ref.watch(ordersViewIsEmptyProvider);
    final showOrderFab =
        _selectedIndex == 1 && orders.isNotEmpty && !ordersViewEmpty;
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      // Plain IndexedStack (no AnimatedSwitcher): the switcher recreated the
      // stack's children on every shell rebuild, throwing away each tab's
      // State (e.g. the Orders screen's selected date kept resetting to today).
      // IndexedStack keeps all tabs alive and preserves their state.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      floatingActionButton: !showOrderFab
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/owner/orders/create'),
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 10,
              child: const Icon(Icons.add_rounded, size: 26),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: PillBottomNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          PillNavDestination(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Home',
          ),
          PillNavDestination(
            icon: CupertinoIcons.bag,
            selectedIcon: CupertinoIcons.bag_fill,
            label: 'Orders',
          ),
          PillNavDestination(
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            label: 'Customers',
          ),
          PillNavDestination(
            icon: CupertinoIcons.chart_bar,
            selectedIcon: CupertinoIcons.chart_bar_fill,
            label: 'Reports',
          ),
          PillNavDestination(
            icon: CupertinoIcons.person,
            selectedIcon: CupertinoIcons.person_fill,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

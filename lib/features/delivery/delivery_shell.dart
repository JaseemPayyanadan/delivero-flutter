import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/order_settings_provider.dart';
import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/pill_bottom_nav_bar.dart';
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
      bottomNavigationBar: PillBottomNavBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(deliveryNavIndexProvider.notifier).setIndex(index),
        destinations: const [
          PillNavDestination(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Dashboard',
          ),
          PillNavDestination(
            icon: CupertinoIcons.bag,
            selectedIcon: CupertinoIcons.bag_fill,
            label: 'Orders',
          ),
          PillNavDestination(
            icon: CupertinoIcons.person,
            selectedIcon: CupertinoIcons.person_fill,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

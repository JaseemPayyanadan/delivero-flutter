import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/driver.dart';

class RouteManagementScreen extends ConsumerStatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  ConsumerState<RouteManagementScreen> createState() =>
      _RouteManagementScreenState();
}

class _RouteManagementScreenState extends ConsumerState<RouteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final drivers = ref.watch(driversProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logistics Control',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${routes.length} active routes • ${drivers.where((d) => d.isActive).length} on-field agents',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'ROUTES'),
                    Tab(text: 'FIELD AGENTS'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _RouteListTab(routes: routes, drivers: drivers),
            _DriverListTab(drivers: drivers),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppColors.secondary,
        elevation: 8,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'NEW ROUTE' : 'REGISTER AGENT',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showRouteDialog();
    } else {
      _showDriverDialog();
    }
  }

  void _showRouteDialog([DeliveryRoute? route]) {
    final isEdit = route != null;
    final nameController = TextEditingController(text: route?.name);
    final areaController = TextEditingController(text: route?.area);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          isEdit ? 'Update Route' : 'Establish New Route',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Route Identifier',
                hintText: 'e.g. Downtown Express',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: areaController,
              decoration: const InputDecoration(
                labelText: 'Operational Area',
                hintText: 'e.g. Central Business District',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
                letterSpacing: 1,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final factoryId =
                  await ref.read(factoryIdProvider.future) ?? 'FAC_00001';

              final newRoute = DeliveryRoute(
                id: isEdit ? route.id : const Uuid().v4(),
                factoryId: factoryId,
                name: nameController.text,
                area: areaController.text,
                description: route?.description ?? '',
                isActive: route?.isActive ?? true,
                estimatedDeliveryTime: route?.estimatedDeliveryTime ?? 30,
                maxOrders: route?.maxOrders ?? 10,
                currentOrders: route?.currentOrders ?? 0,
                assignedDriver: route?.assignedDriver,
                createdAt: route?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );
              if (isEdit) {
                ref.read(routesProvider.notifier).updateRoute(newRoute);
              } else {
                ref.read(routesProvider.notifier).addRoute(newRoute);
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isEdit ? 'UPDATE' : 'ESTABLISH',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverDialog([Driver? driver]) {
    final isEdit = driver != null;
    final nameController = TextEditingController(text: driver?.name);
    final phoneController = TextEditingController(text: driver?.phone);
    VehicleType selectedVehicle = driver?.vehicleType ?? VehicleType.bike;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            isEdit ? 'Update Agent' : 'Onboard New Agent',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Legal Name',
                  hintText: 'e.g. Alexander Pierce',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  hintText: '+91 00000 00000',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<VehicleType>(
                initialValue: selectedVehicle,
                items: VehicleType.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v.name.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedVehicle = val!),
                decoration: const InputDecoration(labelText: 'Asset Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                  letterSpacing: 1,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final factoryId =
                    await ref.read(factoryIdProvider.future) ?? 'FAC_00001';

                final newDriver = Driver(
                  id: isEdit ? driver.id : const Uuid().v4(),
                  factoryId: factoryId,
                  name: nameController.text,
                  phone: phoneController.text,
                  vehicleType: selectedVehicle,
                  isActive: driver?.isActive ?? true,
                  currentRoute: driver?.currentRoute,
                  createdAt: driver?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                if (isEdit) {
                  ref.read(driversProvider.notifier).updateDriver(newDriver);
                } else {
                  ref.read(driversProvider.notifier).addDriver(newDriver);
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEdit ? 'UPDATE' : 'ONBOARD',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteListTab extends ConsumerWidget {
  final List<DeliveryRoute> routes;
  final List<Driver> drivers;
  const _RouteListTab({required this.routes, required this.drivers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routes.isEmpty) {
      return _buildEmptyState(
        Icons.alt_route_rounded,
        'No active logistics routes',
        'Establish your first delivery path to start fulfilling orders.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        final assignedDriver = drivers.firstWhereOrNull(
          (d) => d.id == route.assignedDriver,
        );
        final driverName = assignedDriver?.name ?? 'WAITING FOR ASSIGNMENT';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              onTap: () {}, // Detail view if needed
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                route.area.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(route.isActive),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      border: const Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_circle_rounded,
                              size: 16,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              driverName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: route.assignedDriver != null
                                    ? AppColors.textPrimary
                                    : AppColors.error,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        _buildActionMenu(context, ref, route),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.textDisabled)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.textDisabled,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionMenu(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    return PopupMenuButton(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppColors.textLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        _buildPopupItem('assign', Icons.person_add_rounded, 'Assign Agent'),
        _buildPopupItem('edit', Icons.edit_rounded, 'Modify Route'),
        _buildPopupItem(
          'delete',
          Icons.delete_outline_rounded,
          'Decommission',
          isDestructive: true,
        ),
      ],
      onSelected: (val) {
        if (val == 'assign') _showAssignDialog(context, ref, route);
      },
    );
  }

  PopupMenuItem _buildPopupItem(
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDestructive ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    final availableDrivers = drivers
        .where((d) => d.isActive && d.currentRoute == null)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Select Field Agent',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: availableDrivers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No unassigned agents available in the fleet.'),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = availableDrivers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.backgroundSecondary,
                        child: Text(
                          driver.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        driver.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        driver.vehicleType.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () {
                        final updatedRoute = DeliveryRoute(
                          id: route.id,
                          factoryId: route.factoryId,
                          name: route.name,
                          description: route.description,
                          area: route.area,
                          assignedDriver: driver.id,
                          isActive: route.isActive,
                          estimatedDeliveryTime: route.estimatedDeliveryTime,
                          maxOrders: route.maxOrders,
                          currentOrders: route.currentOrders,
                          createdAt: route.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        ref
                            .read(routesProvider.notifier)
                            .updateRoute(updatedRoute);

                        final updatedDriver = Driver(
                          id: driver.id,
                          factoryId: driver.factoryId,
                          name: driver.name,
                          phone: driver.phone,
                          vehicleType: driver.vehicleType,
                          isActive: driver.isActive,
                          currentRoute: route.id,
                          createdAt: driver.createdAt,
                          updatedAt: DateTime.now(),
                        );
                        ref
                            .read(driversProvider.notifier)
                            .updateDriver(updatedDriver);

                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'DISMISS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverListTab extends ConsumerWidget {
  final List<Driver> drivers;
  const _DriverListTab({required this.drivers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (drivers.isEmpty) {
      return _buildEmptyState(
        Icons.person_off_rounded,
        'No agents registered',
        'Onboard field agents to begin route assignments and delivery operations.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.info),
            ),
            title: Text(
              driver.name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 12,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      driver.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    driver.vehicleType.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Switch.adaptive(
              value: driver.isActive,
              onChanged: (val) {
                final updatedDriver = Driver(
                  id: driver.id,
                  factoryId: driver.factoryId,
                  name: driver.name,
                  phone: driver.phone,
                  vehicleType: driver.vehicleType,
                  isActive: val,
                  currentRoute: driver.currentRoute,
                  createdAt: driver.createdAt,
                  updatedAt: DateTime.now(),
                );
                ref.read(driversProvider.notifier).updateDriver(updatedDriver);
              },
              activeThumbColor: AppColors.success,
              activeTrackColor: AppColors.success.withValues(alpha: 0.4),
            ),
          ),
        );
      },
    );
  }
}

Widget _buildEmptyState(IconData icon, String title, String subtitle) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(icon, size: 64, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

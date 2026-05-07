import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/primary_square_icon_button.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/driver.dart';
import 'widgets/management_search_filters.dart';
import 'widgets/route_card.dart';

class RouteManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const RouteManagementScreen({super.key, this.initialTabIndex = 0});

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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
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
    final routesLoaded = ref.watch(routesLoadedProvider);
    final driversLoaded = ref.watch(driversLoadedProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(routesProvider.notifier).refresh(),
            ref.read(driversProvider.notifier).refresh(),
          ]);
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            DeliveroSliverHeader(
              title: 'Routes & drivers',
              subtitle:
                  '${routes.length} routes • ${drivers.where((d) => d.isActive).length} drivers on duty',
              expandedHeight: 140,
              floating: true,
              pinned: true,
              actions: [
                PrimarySquareIconButton(
                  icon: Icons.add_rounded,
                  onPressed: () => _showAddDialog(),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.alt_route_rounded, size: 18),
                        text: 'Routes',
                      ),
                      Tab(
                        icon: const Icon(
                          Icons.person_pin_circle_rounded,
                          size: 18,
                        ),
                        text: 'Drivers',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _RouteListTab(
                routes: routes,
                drivers: drivers,
                routesLoaded: routesLoaded,
              ),
              _DriverListTab(drivers: drivers, driversLoaded: driversLoaded),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showRouteDialog();
    } else {
      _showAddEditDriverDialog(context, ref);
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
          isEdit ? 'Edit route' : 'Add route',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Route name',
                hintText: 'e.g. Downtown Express',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: areaController,
              decoration: const InputDecoration(
                labelText: 'Area',
                hintText: 'e.g. Central Business District',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.2,
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
            child: Text(isEdit ? 'Save' : 'Add route'),
          ),
        ],
      ),
    );
  }
}

class _RouteListTab extends ConsumerWidget {
  final List<DeliveryRoute> routes;
  final List<Driver> drivers;
  final bool routesLoaded;
  const _RouteListTab({
    required this.routes,
    required this.drivers,
    required this.routesLoaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Local search/filter state kept in widget tree to avoid global providers.
    return _RouteListTabBody(
      routes: routes,
      drivers: drivers,
      routesLoaded: routesLoaded,
    );
  }
}

class _RouteListTabBody extends ConsumerStatefulWidget {
  final List<DeliveryRoute> routes;
  final List<Driver> drivers;
  final bool routesLoaded;
  const _RouteListTabBody({
    required this.routes,
    required this.drivers,
    required this.routesLoaded,
  });

  @override
  ConsumerState<_RouteListTabBody> createState() => _RouteListTabBodyState();
}

enum _RouteFilter { all, active, inactive }

class _RouteListTabBodyState extends ConsumerState<_RouteListTabBody> {
  final TextEditingController _search = TextEditingController();
  String _q = '';
  _RouteFilter _filter = _RouteFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(DeliveryRoute route, String driverName) {
    if (_filter == _RouteFilter.active && !route.isActive) return false;
    if (_filter == _RouteFilter.inactive && route.isActive) return false;
    final query = _q.trim().toLowerCase();
    if (query.isEmpty) return true;
    return route.name.toLowerCase().contains(query) ||
        route.area.toLowerCase().contains(query) ||
        driverName.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final routes = widget.routes;
    final drivers = widget.drivers;
    final routesLoaded = widget.routesLoaded;

    if (!routesLoaded && routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (routes.isEmpty) {
      return _buildEmptyState(
        Icons.alt_route_rounded,
        'No routes yet',
        'Add a route so you can assign drivers and deliveries.',
      );
    }

    final visible =
        <({DeliveryRoute route, Driver? driver, String driverName})>[];
    for (final route in routes) {
      final assignedDriver = drivers.firstWhereOrNull(
        (d) => d.id == route.assignedDriver,
      );
      final driverName = assignedDriver?.name ?? 'No driver yet';
      if (_matches(route, driverName)) {
        visible.add((
          route: route,
          driver: assignedDriver,
          driverName: driverName,
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 72),
      children: [
        ManagementSearchFilters(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          chips: [
            ManagementFilterChip(
              label: 'All',
              selected: _filter == _RouteFilter.all,
              onTap: () => setState(() => _filter = _RouteFilter.all),
            ),
            ManagementFilterChip(
              label: 'Active',
              selected: _filter == _RouteFilter.active,
              onTap: () => setState(() => _filter = _RouteFilter.active),
            ),
            ManagementFilterChip(
              label: 'Inactive',
              selected: _filter == _RouteFilter.inactive,
              onTap: () => setState(() => _filter = _RouteFilter.inactive),
            ),
          ],
        ),
        ...visible.map((e) {
          final route = e.route;
          final driverName = e.driverName;
          final driver = e.driver;
          final hasDriver =
              route.assignedDriver != null && route.assignedDriver!.isNotEmpty;
          return RouteCard(
            route: route,
            driverName: driverName,
            hasDriver: hasDriver,
            vehicleTypeLabel: driver == null
                ? null
                : '${driver.vehicleType.name[0].toUpperCase()}${driver.vehicleType.name.substring(1)}',
            vehicleType: driver?.vehicleType,
            onTap: () => _showRouteDetails(context, route, driverName),
            onAssign: () => _showAssignDialog(context, ref, route),
            trailingMenu: _buildActionMenu(context, ref, route),
          );
        }),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: _buildEmptyState(
              Icons.search_off_rounded,
              'No matches',
              'Try a different keyword or filter.',
            ),
          ),
      ],
    );
  }

  // Status badge moved into `RouteCard`.

  Widget _buildActionMenu(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: AppColors.textLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        _menuItem('assign', Icons.person_add_rounded, 'Assign driver'),
        _menuItem('edit', Icons.edit_rounded, 'Edit route'),
        _menuItem(
          'delete',
          Icons.delete_outline_rounded,
          'Remove route',
          isDestructive: true,
        ),
      ],
      onSelected: (val) {
        if (val == 'assign') _showAssignDialog(context, ref, route);
        if (val == 'edit') _showEditRouteDialog(context, ref, route);
        if (val == 'delete') _confirmDeleteRoute(context, ref, route);
      },
    );
  }

  void _showAssignDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    final availableDrivers = ref
        .read(driversProvider)
        .where((d) => d.isActive && d.currentRoute == null)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Choose a driver',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: availableDrivers.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No free drivers right now. Add a driver first.'),
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
                          driver.name.trim().isNotEmpty
                              ? driver.name.trim()[0].toUpperCase()
                              : '?',
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
              'Close',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    final nameController = TextEditingController(text: route.name);
    final areaController = TextEditingController(text: route.area);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Edit route',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Route name'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: areaController,
              decoration: const InputDecoration(labelText: 'Area'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.2,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = DeliveryRoute(
                id: route.id,
                factoryId: route.factoryId,
                name: nameController.text.trim(),
                description: route.description,
                area: areaController.text.trim(),
                assignedDriver: route.assignedDriver,
                isActive: route.isActive,
                estimatedDeliveryTime: route.estimatedDeliveryTime,
                maxOrders: route.maxOrders,
                currentOrders: route.currentOrders,
                createdAt: route.createdAt,
                updatedAt: DateTime.now(),
              );
              ref.read(routesProvider.notifier).updateRoute(updated);
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      nameController.dispose();
      areaController.dispose();
    });
  }

  void _confirmDeleteRoute(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Remove this route?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Delete "${route.name}" for good? Any driver on this route will be unassigned.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep it',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final assignedDriverId = route.assignedDriver;
              if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
                final driver = ref
                    .read(driversProvider)
                    .firstWhereOrNull((d) => d.id == assignedDriverId);
                if (driver != null) {
                  final updatedDriver = Driver(
                    id: driver.id,
                    factoryId: driver.factoryId,
                    name: driver.name,
                    phone: driver.phone,
                    vehicleType: driver.vehicleType,
                    isActive: driver.isActive,
                    currentRoute: null,
                    createdAt: driver.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  ref
                      .read(driversProvider.notifier)
                      .updateDriver(updatedDriver);
                }
              }
              ref.read(routesProvider.notifier).deleteRoute(route.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
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

  void _showRouteDetails(
    BuildContext context,
    DeliveryRoute route,
    String driverName,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.sectionHeader.copyWith(
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              _detailRow('Driver', driverName),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.appTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.appTextStyles.sectionHeader.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// Info chip moved into `RouteCard`.

// Filter chips extracted to widgets/management_search_filters.dart

class _DriverListTab extends ConsumerWidget {
  final List<Driver> drivers;
  final bool driversLoaded;
  const _DriverListTab({required this.drivers, required this.driversLoaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    if (!driversLoaded && drivers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (drivers.isEmpty) {
      return _buildEmptyState(
        Icons.person_off_rounded,
        'No drivers yet',
        'Add drivers here, then you can assign them to routes.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 72),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final routeName = !routesLoaded || driver.currentRoute == null
            ? null
            : routes.firstWhereOrNull((r) => r.id == driver.currentRoute)?.name;
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
            leading: SizedBox(
              width: 60,
              height: 60,
              child: Image.asset(
                _vehicleAsset(driver.vehicleType),
                fit: BoxFit.contain,
              ),
            ),
            onTap: () => _showAddEditDriverDialog(context, ref, driver: driver),
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
                if (routeName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.alt_route_rounded,
                        size: 12,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          routeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textLight,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                _menuItem('edit', Icons.edit_rounded, 'Edit driver'),
                _menuItem(
                  'toggle',
                  driver.isActive
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  driver.isActive ? 'Set unavailable' : 'Set available',
                ),
                _menuItem(
                  'delete',
                  Icons.delete_outline_rounded,
                  'Delete driver',
                  isDestructive: true,
                ),
              ],
              onSelected: (val) async {
                if (val == 'edit') {
                  _showAddEditDriverDialog(context, ref, driver: driver);
                  return;
                }
                if (val == 'toggle') {
                  final updated = Driver(
                    id: driver.id,
                    factoryId: driver.factoryId,
                    name: driver.name,
                    phone: driver.phone,
                    vehicleType: driver.vehicleType,
                    isActive: !driver.isActive,
                    currentRoute: driver.currentRoute,
                    createdAt: driver.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  ref.read(driversProvider.notifier).updateDriver(updated);
                  return;
                }
                if (val == 'delete') {
                  final confirmed = await _confirmDeleteDriver(context);
                  if (confirmed == true) {
                    ref.read(driversProvider.notifier).deleteDriver(driver.id);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDeleteDriver(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Delete this driver?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'They will be removed from your team. You cannot undo this.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep them',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildEmptyState(IconData icon, String title, String subtitle) {
  return DeliveroEmptyState(title: title, subtitle: subtitle, icon: icon);
}

PopupMenuItem<String> _menuItem(
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

String _vehicleAsset(VehicleType type) {
  switch (type) {
    case VehicleType.bike:
      return 'assets/images/scooty.png';
    case VehicleType.scooter:
      return 'assets/images/scooter.webp';
    case VehicleType.auto:
      return 'assets/images/auto.png';
    case VehicleType.van:
      return 'assets/images/scooter.webp';
  }
}

void _showAddEditDriverDialog(
  BuildContext context,
  WidgetRef ref, {
  Driver? driver,
}) {
  final isEdit = driver != null;
  final nameController = TextEditingController(text: driver?.name);
  final phoneController = TextEditingController(text: driver?.phone);
  VehicleType selectedVehicle = driver?.vehicleType ?? VehicleType.bike;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          isEdit ? 'Edit driver' : 'Add driver',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Image.asset(
                _vehicleAsset(selectedVehicle),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Rahul Kumar',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
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
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Image.asset(
                              _vehicleAsset(v),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            v.name.isEmpty
                                ? v.name
                                : '${v.name[0].toUpperCase()}${v.name.substring(1)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => selectedVehicle = val!),
              decoration: const InputDecoration(labelText: 'Vehicle'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 0.2,
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
              isEdit ? 'Save' : 'Add driver',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    nameController.dispose();
    phoneController.dispose();
  });
}

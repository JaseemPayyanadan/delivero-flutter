import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/driver.dart';
import 'widgets/add_edit_driver_sheet.dart';
import 'widgets/management_search_filters.dart';
import 'widgets/route_card.dart';
import 'widgets/routes_hub_overview.dart';

InputDecoration _mgmtInputDecoration({required String label, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.backgroundSecondary,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshLists() async {
    await Future.wait([
      ref.read(routesProvider.notifier).refresh(),
      ref.read(driversProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final drivers = ref.watch(driversProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final driversLoaded = ref.watch(driversLoadedProvider);
    final onDuty = drivers.where((d) => d.isActive).length;
    final routesWithoutDriverCount = routes
        .where(
          (r) => r.assignedDriver == null || r.assignedDriver!.trim().isEmpty,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Routes & drivers',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: _tabController.index == 0 ? 'Add route' : 'Add driver',
            onPressed: () {
              try {
                HapticFeedback.lightImpact();
              } catch (_) {}
              _showAddDialog();
            },
            icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutesHubOverviewCard(
            routesCount: routes.length,
            driversOnDuty: onDuty,
            routesWithoutDriver: routesWithoutDriverCount,
          ),
          RoutesHubSegmentedControl(controller: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RouteListTab(
                  routes: routes,
                  drivers: drivers,
                  routesLoaded: routesLoaded,
                  onRefresh: _refreshLists,
                  onEmptyAddRoute: () => _showRouteDialog(),
                ),
                _DriverListTab(
                  drivers: drivers,
                  driversLoaded: driversLoaded,
                  onRefresh: _refreshLists,
                  onEmptyAddDriver: () => showAddEditDriverSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showRouteDialog();
    } else {
      showAddEditDriverSheet(context);
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
          isEdit ? 'Edit route' : 'New route',
          style: context.appTextStyles.sectionHeader,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit
                    ? 'Update how this route appears when assigning orders.'
                    : 'Create a route, then assign an available driver.',
                style: context.appTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _mgmtInputDecoration(
                  label: 'Route name',
                  hint: 'e.g. Downtown Express',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: areaController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _mgmtInputDecoration(
                  label: 'Area / zone',
                  hint: 'e.g. Central Business District',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: context.appTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final factoryId =
                  await ref.read(factoryIdProvider.future) ?? 'FAC_00001';

              final newRoute = DeliveryRoute(
                id: isEdit ? route.id : const Uuid().v4(),
                factoryId: factoryId,
                name: nameController.text.trim(),
                area: areaController.text.trim(),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isEdit ? 'Save changes' : 'Create route',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
  final Future<void> Function() onRefresh;
  final VoidCallback onEmptyAddRoute;
  const _RouteListTab({
    required this.routes,
    required this.drivers,
    required this.routesLoaded,
    required this.onRefresh,
    required this.onEmptyAddRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RouteListTabBody(
      routes: routes,
      drivers: drivers,
      routesLoaded: routesLoaded,
      onRefresh: onRefresh,
      onEmptyAddRoute: onEmptyAddRoute,
    );
  }
}

class _RouteListTabBody extends ConsumerStatefulWidget {
  final List<DeliveryRoute> routes;
  final List<Driver> drivers;
  final bool routesLoaded;
  final Future<void> Function() onRefresh;
  final VoidCallback onEmptyAddRoute;
  const _RouteListTabBody({
    required this.routes,
    required this.drivers,
    required this.routesLoaded,
    required this.onRefresh,
    required this.onEmptyAddRoute,
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
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }
    if (routes.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                Icons.alt_route_rounded,
                'No routes yet',
                'Create a route to organize deliveries and assign drivers.',
                actionLabel: 'Add route',
                onAction: widget.onEmptyAddRoute,
              ),
            ),
          ],
        ),
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
        children: [
          ManagementSearchFilters(
            controller: _search,
            onChanged: (v) => setState(() => _q = v),
            hintText: 'Search routes, areas, drivers…',
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
          Text('Your routes', style: context.appTextStyles.sectionHeader),
          const SizedBox(height: 4),
          Text(
            '${visible.length} shown',
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map((e) {
            final route = e.route;
            final driverName = e.driverName;
            final driver = e.driver;
            final hasDriver =
                route.assignedDriver != null &&
                route.assignedDriver!.isNotEmpty;
            return RouteCard(
              route: route,
              driverName: driverName,
              hasDriver: hasDriver,
              vehicleTypeLabel: driver == null
                  ? null
                  : '${driver.vehicleType.name[0].toUpperCase()}${driver.vehicleType.name.substring(1)}',
              vehicleType: driver?.vehicleType,
              onTap: () => _showRouteDetails(context, ref, route, driverName),
              onAssign: () => _showAssignSheet(context, ref, route),
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
      ),
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
        if (val == 'assign') _showAssignSheet(context, ref, route);
        if (val == 'edit') _showEditRouteDialog(context, ref, route);
        if (val == 'delete') _confirmDeleteRoute(context, ref, route);
      },
    );
  }

  void _showAssignSheet(
    BuildContext context,
    WidgetRef ref,
    DeliveryRoute route,
  ) {
    final availableDrivers = ref
        .read(driversProvider)
        .where((d) => d.isActive && (d.currentRoute?.trim().isEmpty ?? true))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assign driver',
                                style: sheetContext.appTextStyles.sectionHeader,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                route.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sheetContext.appTextStyles.caption
                                    .copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textLight,
                        ),
                      ],
                    ),
                  ),
                  if (availableDrivers.isEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Center(
                          child: Text(
                            'No available drivers without a route. Add a driver or set someone to available.',
                            textAlign: TextAlign.center,
                            style: sheetContext.appTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: availableDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = availableDrivers[index];
                          final initial = driver.name.trim().isNotEmpty
                              ? driver.name.trim()[0].toUpperCase()
                              : '?';
                          final vehicleLabel =
                              '${driver.vehicleType.name[0].toUpperCase()}${driver.vehicleType.name.substring(1)}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  final updatedRoute = DeliveryRoute(
                                    id: route.id,
                                    factoryId: route.factoryId,
                                    name: route.name,
                                    description: route.description,
                                    area: route.area,
                                    assignedDriver: driver.id,
                                    isActive: route.isActive,
                                    estimatedDeliveryTime:
                                        route.estimatedDeliveryTime,
                                    maxOrders: route.maxOrders,
                                    currentOrders: route.currentOrders,
                                    createdAt: route.createdAt,
                                    updatedAt: DateTime.now(),
                                  );
                                  ref
                                      .read(routesProvider.notifier)
                                      .updateRoute(updatedRoute);

                                  final updatedDriver = driver.copyWith(
                                    currentRoute: route.id,
                                    updatedAt: DateTime.now(),
                                  );
                                  ref
                                      .read(driversProvider.notifier)
                                      .updateDriver(updatedDriver);

                                  try {
                                    HapticFeedback.mediumImpact();
                                  } catch (_) {}
                                  Navigator.pop(sheetContext);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              driver.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$vehicleLabel · ${driver.phone}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textLight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
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
        title: Text('Edit route', style: context.appTextStyles.sectionHeader),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _mgmtInputDecoration(label: 'Route name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: areaController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _mgmtInputDecoration(label: 'Area / zone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: context.appTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final nextName = nameController.text.trim();
              if (nextName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a route name.')),
                );
                return;
              }
              final factoryId =
                  await ref.read(factoryIdProvider.future) ?? 'FAC_00001';
              if (!context.mounted) return;
              final updated = DeliveryRoute(
                id: route.id,
                factoryId: factoryId,
                name: nextName,
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w900),
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
          'Delete "${route.name}" for good? Any driver on this route will be removed from the route.',
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
                  final updatedDriver = driver.copyWith(
                    currentRoute: null,
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
    WidgetRef ref,
    DeliveryRoute route,
    String driverName,
  ) {
    final hasDriver =
        route.assignedDriver != null && route.assignedDriver!.isNotEmpty;
    final statusLabel = route.isActive ? 'Active' : 'Inactive';
    final statusColor = route.isActive
        ? AppColors.success
        : AppColors.textSecondary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12 + bottomInset,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.alt_route_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.appTextStyles.sectionHeader,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                route.area.trim().isEmpty
                                    ? 'No area set'
                                    : route.area.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.appTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _routeDetailTile(
                            context,
                            label: 'Status',
                            value: statusLabel,
                            valueColor: statusColor,
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _routeDetailTile(
                            context,
                            label: 'Driver',
                            value: driverName,
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _routeDetailTile(
                            context,
                            label: 'Capacity',
                            value:
                                'Up to ${route.maxOrders} orders · ~${route.estimatedDeliveryTime} min',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!hasDriver)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!context.mounted) return;
                                  _showAssignSheet(context, ref, route);
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Assign driver',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _routeDetailTile(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: context.appTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.appTextStyles.body.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppColors.textPrimary,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

// Info chip moved into `RouteCard`.

// Filter chips extracted to widgets/management_search_filters.dart

enum _DriverFilter { all, available, offDuty }

class _DriverListTab extends ConsumerStatefulWidget {
  final List<Driver> drivers;
  final bool driversLoaded;
  final Future<void> Function() onRefresh;
  final VoidCallback onEmptyAddDriver;
  const _DriverListTab({
    required this.drivers,
    required this.driversLoaded,
    required this.onRefresh,
    required this.onEmptyAddDriver,
  });

  @override
  ConsumerState<_DriverListTab> createState() => _DriverListTabState();
}

class _DriverListTabState extends ConsumerState<_DriverListTab> {
  final TextEditingController _driverSearch = TextEditingController();
  String _driverQ = '';
  _DriverFilter _driverFilter = _DriverFilter.all;

  @override
  void dispose() {
    _driverSearch.dispose();
    super.dispose();
  }

  bool _matchesDriverFilter(Driver d) {
    return switch (_driverFilter) {
      _DriverFilter.all => true,
      _DriverFilter.available => d.isActive,
      _DriverFilter.offDuty => !d.isActive,
    };
  }

  bool _driverMatchesSearch(Driver d) {
    if (!_matchesDriverFilter(d)) return false;
    final q = _driverQ.trim().toLowerCase();
    if (q.isEmpty) return true;
    final vt =
        '${d.vehicleType.name[0].toUpperCase()}${d.vehicleType.name.substring(1)}';
    return d.name.toLowerCase().contains(q) ||
        d.phone.contains(_driverQ.trim()) ||
        vt.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(routesProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    if (!widget.driversLoaded && widget.drivers.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }
    if (widget.drivers.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                Icons.groups_outlined,
                'Build your delivery team',
                'Add drivers, set their vehicle, then assign them to routes from the Routes tab.',
                actionLabel: 'Add driver',
                onAction: widget.onEmptyAddDriver,
              ),
            ),
          ],
        ),
      );
    }

    final visible = widget.drivers.where(_driverMatchesSearch).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
        children: [
          ManagementSearchFilters(
            controller: _driverSearch,
            onChanged: (v) => setState(() => _driverQ = v),
            hintText: 'Search drivers, phone, vehicle…',
            chips: [
              ManagementFilterChip(
                label: 'All',
                selected: _driverFilter == _DriverFilter.all,
                onTap: () => setState(() => _driverFilter = _DriverFilter.all),
              ),
              ManagementFilterChip(
                label: 'Available',
                selected: _driverFilter == _DriverFilter.available,
                onTap: () =>
                    setState(() => _driverFilter = _DriverFilter.available),
              ),
              ManagementFilterChip(
                label: 'Off duty',
                selected: _driverFilter == _DriverFilter.offDuty,
                onTap: () =>
                    setState(() => _driverFilter = _DriverFilter.offDuty),
              ),
            ],
          ),
          Text('Your team', style: context.appTextStyles.sectionHeader),
          const SizedBox(height: 4),
          Text(
            '${visible.length} shown',
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map((driver) {
            final routeName =
                !routesLoaded || (driver.currentRoute?.trim().isEmpty ?? true)
                ? null
                : routes
                      .firstWhereOrNull((r) => r.id == driver.currentRoute)
                      ?.name;
            final vehicleLabel =
                '${driver.vehicleType.name[0].toUpperCase()}${driver.vehicleType.name.substring(1)}';

            final statusBg = driver.isActive
                ? AppColors.success
                : AppColors.backgroundSecondary;
            final statusFg = driver.isActive
                ? Colors.white
                : AppColors.textSecondary;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showAddEditDriverSheet(context, driver: driver),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: AppColors.backgroundSecondary,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  _vehicleAsset(driver.vehicleType),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    vehicleLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                driver.isActive ? 'Available' : 'Off duty',
                                style: TextStyle(
                                  color: statusFg,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 20,
                                color: AppColors.textLight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              itemBuilder: (context) => [
                                _menuItem(
                                  'edit',
                                  Icons.edit_rounded,
                                  'Edit driver',
                                ),
                                _menuItem(
                                  'share_login',
                                  Icons.chat_rounded,
                                  'Share sign-in (WhatsApp)',
                                ),
                                _menuItem(
                                  'toggle',
                                  driver.isActive
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.play_circle_outline_rounded,
                                  driver.isActive
                                      ? 'Set unavailable'
                                      : 'Set available',
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
                                  showAddEditDriverSheet(
                                    context,
                                    driver: driver,
                                  );
                                  return;
                                }
                                if (val == 'share_login') {
                                  showReshareDriverLoginDialog(
                                    context,
                                    driver: driver,
                                  );
                                  return;
                                }
                                if (val == 'toggle') {
                                  final updated = driver.copyWith(
                                    isActive: !driver.isActive,
                                    updatedAt: DateTime.now(),
                                  );
                                  ref
                                      .read(driversProvider.notifier)
                                      .updateDriver(updated);
                                  return;
                                }
                                if (val == 'delete') {
                                  final confirmed = await _confirmDeleteDriver(
                                    context,
                                  );
                                  if (confirmed == true) {
                                    ref
                                        .read(driversProvider.notifier)
                                        .deleteDriver(driver.id);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Phone',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            driver.phone,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Current route',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            routeName ?? 'No route',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              letterSpacing: -0.3,
                                              color: routeName == null
                                                  ? AppColors.textLight
                                                  : AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: AppColors.border.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Summary',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                    letterSpacing: 0.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    vehicleLabel,
                                    if (routeName != null) 'Route: $routeName',
                                    driver.isActive
                                        ? 'On duty'
                                        : 'Not taking orders',
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: _buildEmptyState(
                Icons.search_off_rounded,
                'No matches',
                'Try another search or filter.',
              ),
            ),
        ],
      ),
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

Widget _buildEmptyState(
  IconData icon,
  String title,
  String subtitle, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return DeliveroEmptyState(
    title: title,
    subtitle: subtitle,
    icon: icon,
    actionLabel: actionLabel,
    onActionPressed: onAction,
  );
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

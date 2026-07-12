import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../../data/models/order.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/product_unit.dart';

class FoodItemsScreen extends ConsumerStatefulWidget {
  const FoodItemsScreen({super.key});

  @override
  ConsumerState<FoodItemsScreen> createState() => _FoodItemsScreenState();
}

class _FoodItemsScreenState extends ConsumerState<FoodItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProductSort _sort = _ProductSort.nameAsc;
  ProductUnit? _unitFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodItems = ref.watch(foodItemsProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final filteredItems = foodItems
        .where((item) => item.name.toLowerCase().contains(normalizedQuery))
        .where((item) => _unitFilter == null || item.unit == _unitFilter)
        .toList();

    filteredItems.sort((a, b) {
      switch (_sort) {
        case _ProductSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _ProductSort.priceAsc:
          return a.price.compareTo(b.price);
        case _ProductSort.priceDesc:
          return b.price.compareTo(a.price);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: () => ref.read(foodItemsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            DeliveroSliverHeader(
              title: 'Products',
              subtitle: 'Your sellable catalog',
              expandedHeight: 140,
              floating: true,
              pinned: true,
              actions: [
                PopupMenuButton<_ProductSort>(
                  icon: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onSelected: (val) => setState(() => _sort = val),
                  itemBuilder: (context) => [
                    _buildSortMenuItem(_ProductSort.nameAsc, 'Name (A–Z)'),
                    _buildSortMenuItem(
                      _ProductSort.priceAsc,
                      'Price (Low → High)',
                    ),
                    _buildSortMenuItem(
                      _ProductSort.priceDesc,
                      'Price (High → Low)',
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
            if (foodItemsLoaded && foodItems.isNotEmpty)
              SliverToBoxAdapter(child: _buildOverviewCard(foodItems)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search catalog by name...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            if (foodItemsLoaded && foodItems.isNotEmpty)
              SliverToBoxAdapter(child: _buildFilterChips(foodItems)),
            if (!foodItemsLoaded && foodItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context, ref),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = filteredItems[index];
                    return _buildFoodItemRow(context, ref, item);
                  }, childCount: filteredItems.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          _showAddEditDialog(context, ref);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 10,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  PopupMenuItem<_ProductSort> _buildSortMenuItem(
    _ProductSort value,
    String label,
  ) {
    final selected = _sort == value;
    return PopupMenuItem<_ProductSort>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_rounded : Icons.swap_vert_rounded,
            size: 18,
            color: selected ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(List<FoodItem> items) {
    final count = items.length;
    final avgPrice = items.fold<double>(0, (sum, i) => sum + i.price) / count;
    final unitTypes = items.map((i) => i.unit).toSet().length;
    final currency = NumberFormat.decimalPattern();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientEnd,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowDeep,
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'CATALOG OVERVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildOverviewStat('$count', 'Products'),
                _buildOverviewDivider(),
                _buildOverviewStat(
                  '₹${currency.format(avgPrice.round())}',
                  'Avg price',
                ),
                _buildOverviewDivider(),
                _buildOverviewStat('$unitTypes', 'Unit types'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  Widget _buildFilterChips(List<FoodItem> items) {
    final presentUnits = <ProductUnit>[
      for (final u in ProductUnit.values)
        if (items.any((i) => i.unit == u)) u,
    ];
    // No point showing filters when everything shares one unit.
    if (presentUnits.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            _buildFilterChip(null, 'All', items.length),
            for (final u in presentUnits) ...[
              const SizedBox(width: 8),
              _buildFilterChip(
                u,
                _unitLabelShort(u),
                items.where((i) => i.unit == u).length,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(ProductUnit? unit, String label, int count) {
    final selected = _unitFilter == unit;
    final accent = unit == null ? AppColors.primary : _unitColor(unit);
    return GestureDetector(
      onTap: () => setState(() => _unitFilter = unit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : AppColors.border),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItemRow(BuildContext context, WidgetRef ref, FoodItem item) {
    final unitColor = _unitColor(item.unit);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _showAddEditDialog(context, ref, item),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: unitColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_unitIcon(item.unit), color: unitColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: unitColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _unitLabel(item.unit),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: unitColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Updated ${DateFormat('MMM d').format(item.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLight,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    item.unit == ProductUnit.quantity
                        ? '₹${NumberFormat.decimalPattern().format(item.price)}'
                        : '₹${NumberFormat.decimalPattern().format(item.price)} ${item.unit.priceSuffix}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _showItemActions(context, ref, item),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _unitIcon(ProductUnit unit) => switch (unit) {
    ProductUnit.quantity => Icons.inventory_2_rounded,
    ProductUnit.kilogram => Icons.scale_rounded,
    ProductUnit.gram => Icons.scale_rounded,
    ProductUnit.litre => Icons.water_drop_rounded,
  };

  static Color _unitColor(ProductUnit unit) => switch (unit) {
    ProductUnit.quantity => AppColors.primary,
    ProductUnit.kilogram => AppColors.success,
    ProductUnit.gram => AppColors.success,
    ProductUnit.litre => AppColors.info,
  };

  static String _unitLabel(ProductUnit unit) => switch (unit) {
    ProductUnit.quantity => 'PER PIECE',
    ProductUnit.kilogram => 'PER KG',
    ProductUnit.gram => 'PER GRAM',
    ProductUnit.litre => 'PER LITRE',
  };

  static String _unitLabelShort(ProductUnit unit) => switch (unit) {
    ProductUnit.quantity => 'Piece',
    ProductUnit.kilogram => 'Kg',
    ProductUnit.gram => 'Gram',
    ProductUnit.litre => 'Litre',
  };

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isFiltering = _searchQuery.trim().isNotEmpty || _unitFilter != null;
    if (isFiltering) {
      return DeliveroEmptyState(
        title: 'No matching products',
        subtitle:
            'Try a different search or clear the filters to see your full catalog.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Clear filters',
        onActionPressed: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _unitFilter = null;
          });
        },
      );
    }
    return DeliveroEmptyState(
      title: 'Inventory is empty',
      subtitle: 'Add what you sell so you can put it on orders',
      icon: Icons.inventory_2_outlined,
      actionLabel: 'Add product',
      onActionPressed: () => _showAddEditDialog(context, ref),
    );
  }

  void _showItemActions(BuildContext context, WidgetRef ref, FoodItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _showAddEditDialog(this.context, ref, item);
                },
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Edit Product',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                onTap: () async {
                  final sm = ScaffoldMessenger.of(this.context);
                  Navigator.pop(context);
                  // H2: block delete if active orders reference this item
                  const activeStatuses = {
                    OrderStatus.pending,
                    OrderStatus.confirmed,
                    OrderStatus.preparing,
                    OrderStatus.ready,
                  };
                  final activeCount = ref
                      .read(ordersProvider)
                      .where(
                        (o) =>
                            activeStatuses.contains(o.status) &&
                            o.items.any((i) => i.foodItemId == item.id),
                      )
                      .length;
                  if (activeCount > 0) {
                    sm.showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${item.name}" is on $activeCount active order(s). Deliver or cancel them first.',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  final confirmed = await _confirmDelete(this.context, item);
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(foodItemsProvider.notifier)
                          .deleteFoodItem(item.id);
                    } catch (e) {
                      sm.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete product. Try again.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete Product',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, FoodItem item) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Product?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'This removes "${item.name}" from your list. You cannot undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep it',
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

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, [
    FoodItem? item,
  ]) {
    final isEdit = item != null;
    final initialName = item?.name ?? '';
    final initialPrice = item?.price.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return _FoodItemEditorDialog(
          isEdit: isEdit,
          item: item,
          initialName: initialName,
          initialPrice: initialPrice,
          onSave: (name, price, unit) async {
            final factoryId = await ref.read(factoryIdProvider.future);
            if (factoryId == null || factoryId.isEmpty) return false;
            if (isEdit) {
              await ref
                  .read(foodItemsProvider.notifier)
                  .updateFoodItem(
                    FoodItem(
                      id: item.id,
                      factoryId: item.factoryId,
                      name: name,
                      price: price,
                      unit: unit,
                      createdAt: item.createdAt,
                      updatedAt: DateTime.now(),
                    ),
                  );
            } else {
              await ref
                  .read(foodItemsProvider.notifier)
                  .addFoodItem(
                    FoodItem(
                      id: const Uuid().v4(),
                      factoryId: factoryId,
                      name: name,
                      price: price,
                      unit: unit,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
            }
            return true;
          },
          onDelete: isEdit
              ? () async {
                  final sm = ScaffoldMessenger.of(this.context);
                  const activeStatuses = {
                    OrderStatus.pending,
                    OrderStatus.confirmed,
                    OrderStatus.preparing,
                    OrderStatus.ready,
                  };
                  final activeCount = ref
                      .read(ordersProvider)
                      .where(
                        (o) =>
                            activeStatuses.contains(o.status) &&
                            o.items.any((i) => i.foodItemId == item.id),
                      )
                      .length;
                  if (activeCount > 0) {
                    sm.showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${item.name}" is on $activeCount active order(s). Deliver or cancel them first.',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  final confirmed = await _confirmDelete(this.context, item);
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(foodItemsProvider.notifier)
                          .deleteFoodItem(item.id);
                    } catch (e) {
                      sm.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to delete product. Try again.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              : null,
        );
      },
    );
  }
}

class _FoodItemEditorDialog extends StatefulWidget {
  const _FoodItemEditorDialog({
    required this.isEdit,
    required this.item,
    required this.initialName,
    required this.initialPrice,
    required this.onSave,
    this.onDelete,
  });

  final bool isEdit;
  final FoodItem? item;
  final String initialName;
  final String initialPrice;
  final Future<bool> Function(String name, double price, ProductUnit unit)
  onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_FoodItemEditorDialog> createState() => _FoodItemEditorDialogState();
}

class _FoodItemEditorDialogState extends State<_FoodItemEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late ProductUnit _unit;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(text: widget.initialPrice);
    _unit = widget.item?.unit ?? ProductUnit.quantity;
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _nameController.text.trim().isEmpty ? 'Enter a product name' : null;
  }

  String? get _priceError {
    if (!_submitted) return null;
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) return 'Enter a price greater than 0';
    return null;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(name, price, _unit);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  static Color _unitColor(ProductUnit unit) => switch (unit) {
    ProductUnit.quantity => AppColors.primary,
    ProductUnit.kilogram => AppColors.success,
    ProductUnit.gram => AppColors.success,
    ProductUnit.litre => AppColors.info,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _nameController.text.trim() != widget.initialName.trim() ||
        _priceController.text.trim() != widget.initialPrice.trim() ||
        _unit != (widget.item?.unit ?? ProductUnit.quantity);
  }

  Future<void> _closeDialog() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final discard = await confirmDiscardUnsavedChanges(context);
    if (discard && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _unitColor(_unit);
    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(accent),
                const SizedBox(height: 24),
                _buildFieldLabel('Product name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  autofocus: !widget.isEdit,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Premium basmati rice',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('How is it sold?'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final u in ProductUnit.values) ...[
                      if (u != ProductUnit.values.first)
                        const SizedBox(width: 8),
                      Expanded(child: _buildUnitChip(u)),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Unit price'),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    suffixText: _unit == ProductUnit.quantity
                        ? null
                        : _unit.priceSuffix,
                    suffixStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                    errorText: _priceError,
                  ),
                ),
                const SizedBox(height: 28),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            widget.isEdit ? Icons.edit_rounded : Icons.add_rounded,
            color: accent,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEdit ? 'Edit product' : 'Add product',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.isEdit
                    ? 'Update the details for this item'
                    : 'Add an item to your sellable catalog',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _closeDialog,
          icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildUnitChip(ProductUnit u) {
    final selected = _unit == u;
    final color = _unitColor(u);
    return GestureDetector(
      onTap: () => setState(() => _unit = u),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          u.chipLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (widget.isEdit && widget.onDelete != null) ...[
          IconButton(
            onPressed: _saving
                ? null
                : () async {
                    Navigator.pop(context);
                    await widget.onDelete!();
                  },
            tooltip: 'Delete product',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.errorLighter,
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: TextButton(
            onPressed: _saving ? null : _closeDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    widget.isEdit ? 'Save changes' : 'Add product',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

enum _ProductSort { nameAsc, priceAsc, priceDesc }

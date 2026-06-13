import 'package:flutter/material.dart';
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

class FoodItemsScreen extends ConsumerStatefulWidget {
  const FoodItemsScreen({super.key});

  @override
  ConsumerState<FoodItemsScreen> createState() => _FoodItemsScreenState();
}

class _FoodItemsScreenState extends ConsumerState<FoodItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ProductSort _sort = _ProductSort.nameAsc;

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
              subtitle: '${foodItems.length} active inventory items',
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
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ProductSort.nameAsc,
                      child: Text('Sort: Name'),
                    ),
                    PopupMenuItem(
                      value: _ProductSort.priceAsc,
                      child: Text('Sort: Price (Low)'),
                    ),
                    PopupMenuItem(
                      value: _ProductSort.priceDesc,
                      child: Text('Sort: Price (High)'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        backgroundColor: AppColors.secondary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New product',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItemRow(BuildContext context, WidgetRef ref, FoodItem item) {
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
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
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${DateFormat('MMM d').format(item.updatedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                          letterSpacing: 0.2,
                        ),
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
                    '₹${NumberFormat.decimalPattern().format(item.price)}',
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
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
          onSave: (name, price) async {
            final factoryId = await ref.read(factoryIdProvider.future);
            if (factoryId == null || factoryId.isEmpty) return false;
            if (isEdit) {
              await ref.read(foodItemsProvider.notifier).updateFoodItem(
                    FoodItem(
                      id: item!.id,
                      factoryId: item.factoryId,
                      name: name,
                      price: price,
                      createdAt: item.createdAt,
                      updatedAt: DateTime.now(),
                    ),
                  );
            } else {
              await ref.read(foodItemsProvider.notifier).addFoodItem(
                    FoodItem(
                      id: const Uuid().v4(),
                      factoryId: factoryId,
                      name: name,
                      price: price,
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
                            o.items.any((i) => i.foodItemId == item!.id),
                      )
                      .length;
                  if (activeCount > 0) {
                    sm.showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${item!.name}" is on $activeCount active order(s). Deliver or cancel them first.',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  final confirmed = await _confirmDelete(this.context, item!);
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
  final Future<bool> Function(String name, double price) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_FoodItemEditorDialog> createState() => _FoodItemEditorDialogState();
}

class _FoodItemEditorDialogState extends State<_FoodItemEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(text: widget.initialPrice);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    return _nameController.text.trim() != widget.initialName.trim() ||
        _priceController.text.trim() != widget.initialPrice.trim();
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
    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          widget.isEdit ? 'Edit product' : 'Add product',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Premium basmati rice',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _priceController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Unit Price (₹)',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isEdit && widget.onDelete != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await widget.onDelete!();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          TextButton(
            onPressed: _closeDialog,
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
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text) ?? 0;
              if (name.isEmpty || price <= 0) return;
              final ok = await widget.onSave(name, price);
              if (ok && context.mounted) Navigator.pop(context);
            },
            child: Text(widget.isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }
}

enum _ProductSort { nameAsc, priceAsc, priceDesc }

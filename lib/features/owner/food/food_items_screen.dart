import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
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
          if (filteredItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, ref),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filteredItems[index];
                    return _buildFoodItemRow(context, ref, item);
                  },
                  childCount: filteredItems.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        backgroundColor: AppColors.secondary,
        elevation: 8,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'NEW PRODUCT',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItemRow(
    BuildContext context,
    WidgetRef ref,
    FoodItem item,
  ) {
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
                        'UPDATED ${DateFormat('MMM d').format(item.updatedAt).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textLight,
                          letterSpacing: 0.8,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Inventory is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add products to start managing your catalog',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'ADD PRODUCT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
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
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text(
                  'Edit Product',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDelete(this.context, item);
                  if (confirmed == true) {
                    ref.read(foodItemsProvider.notifier).deleteFoodItem(item.id);
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
          'This will permanently remove "${item.name}" from your catalog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
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
    final nameController = TextEditingController(text: item?.name);
    final priceController = TextEditingController(text: item?.price.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          isEdit ? 'Update Product' : 'Register Product',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Commercial Name',
                hintText: 'e.g. Premium Basmati Rice',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: priceController,
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
          if (isEdit)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete(this.context, item);
                if (confirmed == true) {
                  ref.read(foodItemsProvider.notifier).deleteFoodItem(item.id);
                }
              },
              child: const Text(
                'DELETE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.error,
                  letterSpacing: 1,
                ),
              ),
            ),
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
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0;
              if (name.isEmpty || price <= 0) return;

              final factoryId =
                  await ref.read(factoryIdProvider.future) ?? 'FAC_00001';

              final newItem = FoodItem(
                id: isEdit ? item.id : const Uuid().v4(),
                factoryId: factoryId,
                name: name,
                price: price,
                createdAt: item?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              if (isEdit) {
                ref.read(foodItemsProvider.notifier).updateFoodItem(newItem);
              } else {
                ref.read(foodItemsProvider.notifier).addFoodItem(newItem);
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
              isEdit ? 'UPDATE' : 'REGISTER',
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
}

enum _ProductSort { nameAsc, priceAsc, priceDesc }

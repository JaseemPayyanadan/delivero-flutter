part of 'create_order_screen.dart';

class _SelectionSummary {
  final int distinctItems;
  final int totalUnits;
  final double subtotal;

  const _SelectionSummary({
    required this.distinctItems,
    required this.totalUnits,
    required this.subtotal,
  });
}

class _CreateOrderStepProgress extends StatelessWidget {
  final int stepIndex;
  final int stepCount;
  final List<String> labels;

  const _CreateOrderStepProgress({
    required this.stepIndex,
    required this.stepCount,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < stepCount; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= stepIndex
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (i < stepCount - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${labels[stepIndex]} · ${stepIndex + 1}/$stepCount',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReportLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final bool isCustomRate;

  const _ReportLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.isCustomRate,
  });
}

class _OrderReviewReport extends StatelessWidget {
  final DateTime generatedAt;
  final List<_ReportLineItem> lines;
  final double orderTotal;
  final int lineCount;
  final int unitCount;
  final String customerName;
  final String orderTypeLabel;
  final String runLabel;
  final bool isMerge;

  const _OrderReviewReport({
    required this.generatedAt,
    required this.lines,
    required this.orderTotal,
    required this.lineCount,
    required this.unitCount,
    required this.customerName,
    required this.orderTypeLabel,
    required this.runLabel,
    required this.isMerge,
  });

  static TextStyle _label(BuildContext context) => const TextStyle(
    color: AppColors.textLight,
    fontWeight: FontWeight.w900,
    fontSize: 11,
    letterSpacing: 1.2,
  );

  @override
  Widget build(BuildContext context) {
    final prepared = DateFormat('EEE, d MMM yyyy · HH:mm').format(generatedAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            color: AppColors.backgroundSecondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Order summary',
                        style: context.appTextStyles.sectionHeader,
                      ),
                    ),
                  ],
                ),
                if (customerName.isNotEmpty || orderTypeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (customerName.isNotEmpty) customerName,
                      if (runLabel.isNotEmpty) runLabel,
                      if (orderTypeLabel.isNotEmpty) orderTypeLabel,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (isMerge) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Merging into existing order',
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Prepared $prepared · $lineCount line${lineCount == 1 ? '' : 's'} · $unitCount units',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isMerge ? 'Final order · All amounts in INR' : 'All amounts in INR',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('LINE ITEMS', style: _label(context)),
                ),
                const SizedBox(height: 8),
                const _ReportTableHeaderRow(),
                for (var i = 0; i < lines.length; i++) ...[
                  _ReportTableDataRow(line: lines[i]),
                  if (i < lines.length - 1)
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: AppColors.divider,
                    ),
                ],
              ],
            ),
          ),
          Container(width: double.infinity, height: 2, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AMOUNT SUMMARY', style: _label(context)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Expanded(
                      child: Text(
                        'Order total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      formatRupee(orderTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTableHeaderRow extends StatelessWidget {
  const _ReportTableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final s = context.appTextStyles.caption.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 11,
      color: AppColors.textSecondary,
      letterSpacing: 0.35,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: AppColors.backgroundSecondary,
      child: Row(
        children: [
          Expanded(flex: 11, child: Text('ITEM', style: s)),
          Expanded(
            flex: 4,
            child: Text('QTY', style: s, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 5,
            child: Text('RATE', style: s, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 6,
            child: Text('AMOUNT', style: s, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _ReportTableDataRow extends StatelessWidget {
  final _ReportLineItem line;

  const _ReportTableDataRow({required this.line});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (line.isCustomRate)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Custom rate',
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              formatRupee(line.unitPrice),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              formatRupee(line.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _FormSectionCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.appTextStyles.sectionHeader),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: context.appTextStyles.caption.copyWith(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: trailing!,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectedPartnerCard extends StatelessWidget {
  final Customer customer;
  final String routeName;
  final VoidCallback onChange;

  const _SelectedPartnerCard({
    required this.customer,
    required this.routeName,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$routeName • ${customer.phone}',
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
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSuggestions extends StatelessWidget {
  final List<Customer> customers;
  final bool showRouteLoading;
  final List<DeliveryRoute> routes;
  final ValueChanged<Customer> onSelect;
  final String emptyHint;
  final String searchQuery;
  final VoidCallback? onClearSearch;

  const _CustomerSuggestions({
    required this.customers,
    required this.showRouteLoading,
    required this.routes,
    required this.onSelect,
    this.emptyHint = 'No matching customers',
    this.searchQuery = '',
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 24,
              color: AppColors.textLight.withValues(alpha: 0.95),
            ),
            const SizedBox(height: 10),
            Text(
              emptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (searchQuery.isNotEmpty && onClearSearch != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClearSearch,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Clear search',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < customers.length; i++) ...[
            InkWell(
              onTap: () => onSelect(customers[i]),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customers[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: -0.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customers[i].ownerName?.trim().isNotEmpty == true
                                ? customers[i].ownerName!.trim()
                                : 'Owner not added',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${showRouteLoading ? 'Loading route…' : RouteRefs.routeLabelForRef(customers[i].assignedRoute, routes, routesLoaded: !showRouteLoading)} • ${customers[i].phone.trim().isEmpty ? 'No phone' : customers[i].phone.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                  ],
                ),
              ),
            ),
            if (i != customers.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _SelectedMenuItemCard extends StatelessWidget {
  final String name;
  final double unitPrice;
  final bool isCustom;
  final int qty;
  final TextEditingController qtyController;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onCustomPrice;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback? onDuplicate;

  const _SelectedMenuItemCard({
    required this.name,
    required this.unitPrice,
    required this.isCustom,
    required this.qty,
    required this.qtyController,
    required this.onQtyChanged,
    required this.onCustomPrice,
    required this.onDec,
    required this.onInc,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.45,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatRupee(unitPrice),
                      style: TextStyle(
                        color: isCustom
                            ? AppColors.primary
                            : AppColors.textLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onCustomPrice,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter.withValues(
                              alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Custom',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onCustomPrice,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Add custom',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (onDuplicate != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onDuplicate,
                    child: const Text(
                      '+ Add line',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _QtyStepper(
            qty: qty,
            controller: qtyController,
            onQtyChanged: onQtyChanged,
            onDec: onDec,
            onInc: onInc,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final TextEditingController? controller;
  final ValueChanged<int>? onQtyChanged;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _QtyStepper({
    required this.qty,
    this.controller,
    this.onQtyChanged,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: qty > 0 ? onDec : null,
            icon: const Icon(Icons.remove_rounded, size: 16),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: controller == null || onQtyChanged == null
                ? Center(
                    child: Text(
                      qty.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                : TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onEditingComplete: () {
                      final raw = controller!.text.trim();
                      if (raw.isEmpty) {
                        onQtyChanged!(0);
                      } else {
                        final parsed = int.tryParse(raw);
                        if (parsed != null) onQtyChanged!(parsed);
                      }
                      FocusScope.of(context).unfocus();
                    },
                    onSubmitted: (_) {
                      final raw = controller!.text.trim();
                      if (raw.isEmpty) {
                        onQtyChanged!(0);
                      } else {
                        final parsed = int.tryParse(raw);
                        if (parsed != null) onQtyChanged!(parsed);
                      }
                      FocusScope.of(context).unfocus();
                    },
                    onChanged: (val) {
                      final raw = val.trim();
                      if (raw.isEmpty) return;
                      final parsed = int.tryParse(raw);
                      if (parsed == null) return;
                      onQtyChanged!(parsed);
                    },
                  ),
          ),
          IconButton(
            onPressed: onInc,
            icon: const Icon(Icons.add_rounded, size: 16),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  final ScrollController controller;
  final List<FoodItem> items;
  final int Function(String id) getQty;
  final double Function(FoodItem item) getUnitPrice;
  final bool Function(String id) isCustom;
  final void Function(FoodItem item) onCustomPrice;
  final void Function(String id) onInc;
  final void Function(String id) onDec;
  final TextEditingController Function(String id)? getQtyController;
  final void Function(String id, int qty)? onQtyChanged;

  const _CatalogList({
    required this.controller,
    required this.items,
    required this.getQty,
    required this.getUnitPrice,
    required this.isCustom,
    required this.onCustomPrice,
    required this.onInc,
    required this.onDec,
    this.getQtyController,
    this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No catalog matches found',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final qty = getQty(item.id);
        final unitPrice = getUnitPrice(item);
        final custom = isCustom(item.id);
        final controller = getQtyController?.call(item.id);
        if (controller != null && controller.text != qty.toString()) {
          controller.text = qty.toString();
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
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
                        letterSpacing: -0.45,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${formatRupee(unitPrice)} / unit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onCustomPrice(item),
                          style: TextButton.styleFrom(
                            foregroundColor: custom
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            custom ? 'Custom' : 'Add custom',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _QtyStepper(
                qty: qty,
                controller: controller,
                onQtyChanged: onQtyChanged == null
                    ? null
                    : (next) => onQtyChanged!(item.id, next),
                onDec: () => onDec(item.id),
                onInc: () => onInc(item.id),
              ),
            ],
          ),
        );
      },
    );
  }
}

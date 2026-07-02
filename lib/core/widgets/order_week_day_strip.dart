import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../orders/day_strip_math.dart';
import '../theme/app_colors.dart';

/// Fixed height for the swipeable week day strip.
const double kOrderWeekDayStripHeight = 88;

/// Horizontal week-framed day strip for filtering orders by calendar day.
class OrderWeekDayStrip extends StatefulWidget {
  const OrderWeekDayStrip({
    super.key,
    required this.scrollController,
    required this.selectedDate,
    required this.daysWithOrders,
    required this.onDayTap,
    this.onVisibleLeadDateChanged,
    this.onCellWidthChanged,
  });

  final ScrollController scrollController;
  final DateTime? selectedDate;
  final Set<DateTime> daysWithOrders;
  final void Function(DateTime day, bool wasAlreadySelected) onDayTap;
  final ValueChanged<DateTime>? onVisibleLeadDateChanged;
  final ValueChanged<double>? onCellWidthChanged;

  @override
  State<OrderWeekDayStrip> createState() => _OrderWeekDayStripState();
}

class _OrderWeekDayStripState extends State<OrderWeekDayStrip> {
  bool _positioned = false;
  double _cellWidth = 0;

  void _updateVisibleLeadDate() {
    if (!widget.scrollController.hasClients || _cellWidth <= 0) return;
    final leadIndex =
        (widget.scrollController.offset / _cellWidth).round();
    final lead = dayForIndex(DateTime.now(), leadIndex);
    widget.onVisibleLeadDateChanged?.call(lead);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kOrderWeekDayStripHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final now = DateTime.now();
          final todayKey = calendarDayKey(now);
          final cellWidth = constraints.maxWidth / 7;
          if (_cellWidth != cellWidth) {
            _cellWidth = cellWidth;
            widget.onCellWidthChanged?.call(cellWidth);
          }
          if (!_positioned) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  _positioned ||
                  !widget.scrollController.hasClients) {
                return;
              }
              widget.scrollController.jumpTo(
                initialDayStripIndex(now) * cellWidth,
              );
              setState(() => _positioned = true);
              _updateVisibleLeadDate();
            });
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _updateVisibleLeadDate();
                  return false;
                },
                child: ListView.builder(
                  controller: widget.scrollController,
                  scrollDirection: Axis.horizontal,
                  itemExtent: cellWidth,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final day = dayForIndex(now, index);
                    final isSelected = widget.selectedDate == day;
                    return Center(
                      child: OrderDayStripCell(
                        day: day,
                        isToday: day == todayKey,
                        isSelected: isSelected,
                        isPast: day.isBefore(todayKey),
                        hasOrders: widget.daysWithOrders.contains(day),
                        onTap: () =>
                            widget.onDayTap(day, isSelected),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 2,
                child: IgnorePointer(
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: AppColors.textLight.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                child: IgnorePointer(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textLight.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderDayStripCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final bool hasOrders;
  final VoidCallback onTap;

  const OrderDayStripCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
    required this.hasOrders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color nameColor;
    final Color numColor;
    if (isSelected) {
      nameColor = AppColors.primary;
      numColor = Colors.white;
    } else if (isToday) {
      nameColor = AppColors.primary;
      numColor = AppColors.primary;
    } else if (isPast) {
      nameColor = AppColors.textLight;
      numColor = AppColors.textLight;
    } else {
      nameColor = AppColors.textSecondary;
      numColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEE').format(day),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: nameColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primaryLighter
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                day.day.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: numColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: hasOrders
                  ? (isSelected ? Colors.white : AppColors.primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

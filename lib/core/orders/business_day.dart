import '../../data/models/order.dart';

/// Default kitchen-day rollover when no profile setting is stored.
const int kDefaultBusinessDayRolloverHour = 7;

/// Date-only key for the business day that contains [instant].
DateTime businessDayKey(
  DateTime instant, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final base = DateTime(instant.year, instant.month, instant.day);
  if (instant.hour < rolloverHour) {
    return base.subtract(const Duration(days: 1));
  }
  return base;
}

/// Today's business day key (respects the configured rollover).
DateTime currentBusinessDayKey(
  DateTime? reference, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return businessDayKey(
    reference ?? DateTime.now(),
    rolloverHour: rolloverHour,
  );
}

bool isSameBusinessDay(
  DateTime a,
  DateTime b, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return businessDayKey(a, rolloverHour: rolloverHour) ==
      businessDayKey(b, rolloverHour: rolloverHour);
}

/// Whether [scopeDay] (calendar date from UI) matches the order's business day.
bool orderMatchesBusinessScope(
  DateTime orderDate,
  DateTime scopeDay, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final scopeKey = DateTime(scopeDay.year, scopeDay.month, scopeDay.day);
  return businessDayKey(orderDate, rolloverHour: rolloverHour) == scopeKey;
}

/// Local instant when the current calendar day's business period started.
DateTime businessDayRolloverAt(
  DateTime reference, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return DateTime(
    reference.year,
    reference.month,
    reference.day,
    rolloverHour,
  );
}

/// After rollover, orders placed before today's cutoff cannot be merged or edited.
bool canModifyOrderItems(
  Order order, {
  DateTime? referenceTime,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final now = referenceTime ?? DateTime.now();
  if (!isSameBusinessDay(order.orderDate, now, rolloverHour: rolloverHour)) {
    return false;
  }

  final rollover = businessDayRolloverAt(now, rolloverHour: rolloverHour);
  if (now.isBefore(rollover)) return true;
  return !order.orderDate.isBefore(rollover);
}

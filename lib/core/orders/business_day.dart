import 'package:intl/intl.dart';

import '../../data/models/order.dart';

/// Default kitchen-day rollover when no profile setting is stored (7 PM).
const int kDefaultBusinessDayRolloverHour = 19;

String formatOrderRolloverLabel(int hour) {
  final sample = DateTime(2000, 1, 1, hour.clamp(0, 23));
  return DateFormat.jm().format(sample);
}

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
DateTime currentBusinessDayKey({
  DateTime? reference,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return businessDayKey(
    reference ?? DateTime.now(),
    rolloverHour: rolloverHour,
  );
}

/// Previous business day key relative to [reference]'s business day.
DateTime previousBusinessDayKey(
  DateTime reference, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final key = businessDayKey(reference, rolloverHour: rolloverHour);
  return DateTime(
    key.year,
    key.month,
    key.day,
  ).subtract(const Duration(days: 1));
}

/// Rollover instant for a calendar [businessDayKey] (date-only).
DateTime orderDateForBusinessDay(
  DateTime businessDayKey, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return DateTime(
    businessDayKey.year,
    businessDayKey.month,
    businessDayKey.day,
    rolloverHour.clamp(0, 23),
  );
}

/// True when [now] is at or after today's kitchen-day rollover.
bool hasPassedBusinessDayRollover(
  DateTime now, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final rollover = businessDayRolloverAt(now, rolloverHour: rolloverHour);
  return !now.isBefore(rollover);
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
  return DateTime(reference.year, reference.month, reference.day, rolloverHour);
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

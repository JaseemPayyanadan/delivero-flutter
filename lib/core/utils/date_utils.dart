import 'package:cloud_firestore/cloud_firestore.dart';

class DateUtils {
  static DateTime parse(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }
}

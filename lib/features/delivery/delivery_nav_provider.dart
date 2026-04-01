import 'package:flutter_riverpod/flutter_riverpod.dart';

final deliveryNavIndexProvider =
    NotifierProvider<DeliveryNavIndexNotifier, int>(
      DeliveryNavIndexNotifier.new,
    );

class DeliveryNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

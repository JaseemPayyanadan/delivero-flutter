import 'package:flutter/material.dart';

import '../owner/orders/create_order_screen.dart';

class DriverCreateOrderScreen extends StatelessWidget {
  const DriverCreateOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateOrderScreen(forDriver: true);
  }
}

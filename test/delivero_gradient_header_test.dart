import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/core/widgets/delivero_gradient_header.dart';

void main() {
  testWidgets('gradient header renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveroGradientHeader(
              title: 'Order Details',
              subtitle: '#ORD-4583',
              overlapChild: SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('#ORD-4583'), findsOneWidget);
  });

  testWidgets('gradient header without subtitle renders title only', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveroGradientHeader(
              title: 'Order Details',
              overlapChild: SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Order Details'), findsOneWidget);
  });
}

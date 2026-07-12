import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:delivero/data/models/order.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_bottom_actions.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_customer_card.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_payment_section.dart';
import 'package:delivero/features/owner/orders/order_details/widgets/order_detail_summary_card.dart';

final money0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

Order makeOrder({
  OrderStatus status = OrderStatus.pending,
  PaymentStatus? paymentStatus = PaymentStatus.unpaid,
  PaymentMethod? paymentMethod,
  double? amountPaid,
  double totalAmount = 1824,
}) {
  final now = DateTime(2026, 7, 12, 9);
  return Order(
    id: 'ORD-4583',
    factoryId: 'f1',
    orderType: OrderType.daily,
    customerId: 'c1',
    customerName: 'wbc',
    customerEmail: '',
    customerPhone: '9876543210',
    customerAddress: 'Ottappalam, Palakkad, Kerala',
    items: const [
      OrderItem(
        id: 'l1',
        foodItemId: 'i1',
        foodItemName: 'appam',
        quantity: 100,
        unitPrice: 12,
        totalPrice: 1200,
      ),
    ],
    subtotal: totalAmount,
    discountAmount: 0,
    totalAmount: totalAmount,
    paymentStatus: paymentStatus,
    paymentMethod: paymentMethod,
    amountPaid: amountPaid,
    status: status,
    orderDate: now,
    deliveryTime: status == OrderStatus.delivered ? now : null,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpCard(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('OrderDetailSummaryCard', () {
    testWidgets('shows total, due, date and order type', (tester) async {
      final order = makeOrder();
      await pumpCard(
        tester,
        OrderDetailSummaryCard(
          order: order,
          orderIdDisplay: '#ORD-4583',
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          balanceDue: 1824,
        ),
      );
      expect(find.text('Order Total'), findsOneWidget);
      expect(find.text('₹1,824'), findsOneWidget);
      expect(find.text('₹1,824 due'), findsOneWidget);
      expect(find.text('Sunday, 12 Jul 2026'), findsOneWidget);
      expect(find.text('Daily Order'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('paid order hides due line', (tester) async {
      final order = makeOrder(paymentStatus: PaymentStatus.paid, amountPaid: 1824);
      await pumpCard(
        tester,
        OrderDetailSummaryCard(
          order: order,
          orderIdDisplay: '#ORD-4583',
          money0: money0,
          paymentStatus: PaymentStatus.paid,
          balanceDue: 0,
        ),
      );
      expect(find.textContaining('due'), findsNothing);
    });
  });

  group('OrderDetailCustomerCard', () {
    testWidgets('shows initial avatar, name, phone, address and link', (tester) async {
      var viewed = false;
      await pumpCard(
        tester,
        OrderDetailCustomerCard(
          name: 'wbc',
          phone: '9876543210',
          address: 'Ottappalam, Palakkad, Kerala',
          routeLabel: '',
          onViewCustomer: () => viewed = true,
        ),
      );
      expect(find.text('W'), findsOneWidget);
      expect(find.text('wbc'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Ottappalam, Palakkad, Kerala'), findsOneWidget);
      await tester.tap(find.text('View customer'));
      expect(viewed, isTrue);
    });

    testWidgets('hides view-customer link when callback is null', (tester) async {
      await pumpCard(
        tester,
        const OrderDetailCustomerCard(
          name: 'wbc',
          phone: '',
          address: '',
          routeLabel: '',
        ),
      );
      expect(find.text('View customer'), findsNothing);
    });
  });

  group('OrderDetailPaymentCard', () {
    testWidgets('read-only card shows totals and no editor controls', (tester) async {
      final order = makeOrder();
      await pumpCard(
        tester,
        OrderDetailPaymentCard(
          order: order,
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          paymentColor: const Color(0xFFDC2626),
          deliveryFee: 0,
          effectivePaid: 0,
          balanceDue: 1824,
        ),
      );
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('UNPAID'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Update payment'), findsNothing);
    });

    testWidgets('shows update link when callback provided', (tester) async {
      var tapped = false;
      final order = makeOrder(status: OrderStatus.delivered);
      await pumpCard(
        tester,
        OrderDetailPaymentCard(
          order: order,
          money0: money0,
          paymentStatus: PaymentStatus.unpaid,
          paymentColor: const Color(0xFFDC2626),
          deliveryFee: 0,
          effectivePaid: 0,
          balanceDue: 1824,
          onUpdatePayment: () => tapped = true,
        ),
      );
      await tester.tap(find.text('Update payment'));
      expect(tapped, isTrue);
    });
  });

  group('OrderDetailBottomBar', () {
    testWidgets('fires callbacks and disables when delivered', (tester) async {
      var delivered = false;
      var more = false;
      await pumpCard(
        tester,
        OrderDetailBottomBar(
          isDelivered: false,
          onMarkDelivered: () => delivered = true,
          onMore: () => more = true,
        ),
      );
      await tester.tap(find.text('Mark as Delivered'));
      await tester.tap(find.text('More'));
      expect(delivered, isTrue);
      expect(more, isTrue);

      await pumpCard(
        tester,
        OrderDetailBottomBar(
          isDelivered: true,
          onMarkDelivered: () {},
          onMore: () {},
        ),
      );
      expect(find.text('Delivered'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
    });
  });
}

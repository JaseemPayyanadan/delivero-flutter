import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/core/theme/app_colors.dart';
import 'package:delivero/core/widgets/delivero_gradient_header.dart';
import 'package:delivero/core/widgets/delivero_status_chip.dart';
import 'package:delivero/core/widgets/delivero_card.dart';
import 'package:delivero/core/widgets/delivero_button.dart';

// context.appTextStyles falls back to AppTextStyles.light when no theme
// extension is registered, so a plain MaterialApp is enough here.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('DeliveroGradientHeader shows title, avatar and below content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DeliveroGradientHeader(
          title: 'Profile',
          avatar: Text('WW'),
          belowAvatar: Text('Wade Warren'),
        ),
      ),
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('WW'), findsOneWidget);
    expect(find.text('Wade Warren'), findsOneWidget);
  });

  testWidgets('DeliveroGradientHeader card mode shows title and overlap child', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DeliveroGradientHeader(
          title: 'ORD-1024',
          overlapChild: Text('summary card'),
        ),
      ),
    );

    expect(find.text('ORD-1024'), findsOneWidget);
    expect(find.text('summary card'), findsOneWidget);
  });

  testWidgets('DeliveroStatusChip renders its label with the tone color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const DeliveroStatusChip(
          label: 'AVAILABLE',
          tone: StatusChipTone.success,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('AVAILABLE'));
    expect(text.style?.color, AppColors.success);
  });

  testWidgets('DeliveroButton.lime uses the lime secondary color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DeliveroButton.lime(label: 'Generate now', onPressed: () {}),
      ),
    );

    expect(find.text('Generate now'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style?.backgroundColor?.resolve({}),
      AppColors.secondary,
    );
  });

  testWidgets('DeliveroCard renders its child', (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveroCard(child: Text('card body'))),
    );
    expect(find.text('card body'), findsOneWidget);
  });
}

import 'package:delivero/features/onboarding/onboarding_screen.dart';
import 'package:delivero/core/widgets/delivero_gradient_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The onboarding collections (routes/customers/products) only reach out to
// Firebase once a factoryId exists, which requires an authenticated user. With
// the default (signed-out) providers they stay empty and never touch Firebase,
// so the first step renders cleanly for these presentation/validation checks.
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/owner',
          builder: (_, _) => const Scaffold(body: Text('OWNER_HOME')),
        ),
      ],
    );

Widget _harness() =>
    ProviderScope(child: MaterialApp.router(routerConfig: _buildRouter()));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the Fillo gradient header titled "Business setup"',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(DeliveroGradientHeader), findsOneWidget);
    expect(find.text('Business setup'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });

  testWidgets(
      'tapping the CTA with an empty name shows an inline error, not a snackbar',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The step-0 CTA is the purple "Save & next" pill.
    await tester.tap(find.text('Save & next'));
    await tester.pumpAndSettle();

    // Inline validation renders the message in the field's decoration...
    expect(find.text('Please enter your name'), findsOneWidget);
    // ...and does NOT fall back to a transient snackbar.
    expect(find.byType(SnackBar), findsNothing);
    // Still on the setup screen (did not advance).
    expect(find.text('Business setup'), findsOneWidget);
  });

  testWidgets('editing the name clears its inline error', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & next'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Anita Rao');
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsNothing);
  });
}

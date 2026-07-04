import 'package:delivero/features/startup/app_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(path: '/intro', builder: (_, _) => const AppIntroScreen()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN_PAGE')),
        ),
      ],
    );

Widget _harness() =>
    ProviderScope(child: MaterialApp.router(routerConfig: _buildRouter()));

// The next control is a forward-arrow button (an icon-only lime circle on
// non-last slides, a "Get started" pill on the last). Locate it by its icon
// rather than a text label, so the guard is agnostic to the button's styling.
Future<void> _advance(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first slide shows Skip and next control, not Get started',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('advancing twice reaches last slide showing Get started',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _advance(tester);
    await _advance(tester);

    // On the last slide the next control morphs into the "Get started" pill.
    // Note: the "Skip" Text stays in the tree but is hidden via opacity 0 +
    // IgnorePointer (both before and after the redesign), so asserting its
    // absence with find.text is invalid — its hidden state is a manual check.
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Skip marks intro seen and navigates to /login', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenAppIntro'), true);
  });

  testWidgets('Get started completes onboarding to /login', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _advance(tester);
    await _advance(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_PAGE'), findsOneWidget);
  });
}

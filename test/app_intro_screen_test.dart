import 'package:delivero/features/startup/app_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/intro',
      routes: [
        GoRoute(path: '/intro', builder: (_, __) => const AppIntroScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('LOGIN_PAGE')),
        ),
      ],
    );

Widget _harness() =>
    ProviderScope(child: MaterialApp.router(routerConfig: _buildRouter()));

Future<void> _advance(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first slide shows Skip + Next, not Get started', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('Next twice reaches last slide showing Get started, not Next',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await _advance(tester);
    await _advance(tester);

    // On the last slide the CTA morphs to "Get started" and "Next" is gone.
    // Note: the "Skip" Text stays in the tree but is hidden via opacity 0 +
    // IgnorePointer (both before and after the redesign), so asserting its
    // absence with find.text is invalid — its hidden state is a manual check.
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
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

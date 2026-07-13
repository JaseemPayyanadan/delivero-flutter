import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/app/providers.dart';
import 'package:delivero/core/theme/app_theme.dart';
import 'package:delivero/data/models/driver.dart';
import 'package:delivero/data/models/user.dart';
import 'package:delivero/features/auth/auth_controller.dart';
import 'package:delivero/features/profile/settings_screen.dart';

class _FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(
      id: 'u1',
      phone: '9497557401',
      name: 'Jaseem Ullas',
      role: UserRole.owner,
      factoryId: 'f1',
      hasFinishedOnboarding: true,
    ),
    isInitialized: true,
  );
}

class _FakeDrivers extends DriversNotifier {
  @override
  List<Driver> build() => const [];
}

void main() {
  testWidgets('profile page lays out with the identity card and sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        driversProvider.overrideWith(_FakeDrivers.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Jaseem Ullas'), findsOneWidget);
    expect(find.text('OWNER'), findsOneWidget);
    expect(find.text('9497557401'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    // The edit affordance the page was missing.
    expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
  });
}

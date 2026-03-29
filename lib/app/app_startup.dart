import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStartupState {
  final bool hasSeenAppIntro;
  final bool hasSeenOnboarding;
  final bool isInitialized;

  const AppStartupState({
    this.hasSeenAppIntro = false,
    this.hasSeenOnboarding = false,
    this.isInitialized = false,
  });

  AppStartupState copyWith({
    bool? hasSeenAppIntro,
    bool? hasSeenOnboarding,
    bool? isInitialized,
  }) {
    return AppStartupState(
      hasSeenAppIntro: hasSeenAppIntro ?? this.hasSeenAppIntro,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AppStartupNotifier extends Notifier<AppStartupState> {
  static const _kHasSeenAppIntro = 'hasSeenAppIntro';
  static const _kHasSeenOnboarding = 'hasSeenOnboarding';

  SharedPreferences? _prefs;

  @override
  AppStartupState build() {
    return const AppStartupState();
  }

  Future<void> init() async {
    debugPrint('[AppStartup] Initializing...');
    _prefs ??= await SharedPreferences.getInstance();
    final hasSeenAppIntro = _prefs!.getBool(_kHasSeenAppIntro) ?? false;
    final hasSeenOnboarding = _prefs!.getBool(_kHasSeenOnboarding) ?? false;
    debugPrint(
      '[AppStartup] hasSeenAppIntro: $hasSeenAppIntro, hasSeenOnboarding: $hasSeenOnboarding',
    );
    state = AppStartupState(
      hasSeenAppIntro: hasSeenAppIntro,
      hasSeenOnboarding: hasSeenOnboarding,
      isInitialized: true,
    );
  }

  Future<void> markAppIntroSeen() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_kHasSeenAppIntro, true);
    state = state.copyWith(hasSeenAppIntro: true);
  }

  Future<void> markOnboardingSeen() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_kHasSeenOnboarding, true);
    state = state.copyWith(hasSeenOnboarding: true);
  }
}

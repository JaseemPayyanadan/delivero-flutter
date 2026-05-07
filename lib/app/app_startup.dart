import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStartupState {
  final bool hasSeenAppIntro;
  final bool isInitialized;

  const AppStartupState({
    this.hasSeenAppIntro = false,
    this.isInitialized = false,
  });

  AppStartupState copyWith({bool? hasSeenAppIntro, bool? isInitialized}) {
    return AppStartupState(
      hasSeenAppIntro: hasSeenAppIntro ?? this.hasSeenAppIntro,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AppStartupNotifier extends Notifier<AppStartupState> {
  static const _kHasSeenAppIntro = 'hasSeenAppIntro';

  SharedPreferences? _prefs;

  @override
  AppStartupState build() {
    return const AppStartupState();
  }

  Future<void> init() async {
    debugPrint('[AppStartup] Initializing...');
    _prefs ??= await SharedPreferences.getInstance();
    final hasSeenAppIntro = _prefs!.getBool(_kHasSeenAppIntro) ?? false;
    debugPrint('[AppStartup] hasSeenAppIntro: $hasSeenAppIntro');
    state = AppStartupState(
      hasSeenAppIntro: hasSeenAppIntro,
      isInitialized: true,
    );
  }

  Future<void> markAppIntroSeen() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_kHasSeenAppIntro, true);
    state = state.copyWith(hasSeenAppIntro: true);
  }
}

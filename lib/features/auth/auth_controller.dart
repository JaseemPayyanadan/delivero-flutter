import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../data/models/user.dart';
import 'hardcoded_users.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _kUserKey = 'auth_user';
  SharedPreferences? _prefs;

  @override
  AuthState build() {
    // Note: build is sync in v3. Initial state is empty.
    // Use an init method or read from storage on first use if needed.
    return AuthState();
  }

  Future<void> init() async {
    debugPrint('[Auth] Initializing...');
    _prefs ??= await SharedPreferences.getInstance();
    final userJson = _prefs!.getString(_kUserKey);
    if (userJson != null) {
      try {
        final user = User.fromJson(jsonDecode(userJson));
        debugPrint('[Auth] Loaded user: ${user.email}');
        state = state.copyWith(user: user);
      } catch (e) {
        debugPrint('[Auth] Error loading user: $e');
        await _prefs!.remove(_kUserKey);
      }
    } else {
      debugPrint('[Auth] No saved user found');
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    debugPrint('[Auth] Attempting login for $email');

    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      final normalizedEmail = email.toLowerCase().trim();
      final user = hardcodedUsers.firstWhere(
        (u) =>
            u.email.toLowerCase() == normalizedEmail && u.password == password,
        orElse: () => throw Exception('Invalid email or password'),
      );
      debugPrint('[Auth] Login successful: ${user.email}');

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
      debugPrint('[Auth] User saved to SharedPreferences');

      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      debugPrint('[Auth] Login failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Login failed',
      );
    }
  }

  Future<void> logout() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_kUserKey);
    state = AuthState();
  }
}

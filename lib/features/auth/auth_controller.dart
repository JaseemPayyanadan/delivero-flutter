import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/user.dart';
import 'hardcoded_users.dart';
import '../../core/services/firebase_service.dart';

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
  static const _kLocalUsersKey = 'auth_local_users';
  SharedPreferences? _prefs;
  final _uuid = const Uuid();

  @override
  AuthState build() {
    // Note: build is sync in v3. Initial state is empty.
    // Use an init method or read from storage on first use if needed.
    return AuthState();
  }

  Future<void> init() async {
    debugPrint('[Auth] Initializing...');
    _prefs ??= await SharedPreferences.getInstance();

    // Prefer Firebase authenticated session if available.
    try {
      final current = FirebaseService.auth.currentUser;
      if (current != null) {
        final user = await _loadUserFromFirestore(uid: current.uid);
        if (user != null) {
          debugPrint('[Auth] Loaded Firebase user: ${user.email}');
          state = state.copyWith(user: user);
          await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
          return;
        }
      }
    } catch (e) {
      debugPrint('[Auth] Firebase session load skipped: $e');
    }

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
      final normalizedEmail = email.toLowerCase().trim();
      final user =
          await _loginWithFirebase(normalizedEmail, password) ??
          await _loginWithLocalFallback(normalizedEmail, password);

      debugPrint('[Auth] Login successful: ${user.email}');
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
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

  Future<void> registerOwner({
    required String name,
    required String email,
    required String password,
    required String factoryName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final normalizedEmail = email.toLowerCase().trim();

    try {
      final user =
          await _registerWithFirebase(
            name: name,
            email: normalizedEmail,
            password: password,
            factoryName: factoryName,
            phone: phone,
          ) ??
          await _registerWithLocalFallback(
            name: name,
            email: normalizedEmail,
            password: password,
            factoryName: factoryName,
            phone: phone,
          );

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      debugPrint('[Auth] Register failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Registration failed',
      );
    }
  }

  Future<void> completeOnboarding() async {
    if (state.user == null) return;

    final updatedUser = state.user!.copyWith(hasFinishedOnboarding: true);

    try {
      if (FirebaseService.isInitialized && !state.user!.id.startsWith('USR_')) {
        await _saveUserToFirestore(uid: state.user!.id, user: updatedUser);
      }

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kUserKey, jsonEncode(updatedUser.toJson()));

      state = state.copyWith(user: updatedUser);
      debugPrint('[Auth] Onboarding completed for ${updatedUser.email}');
    } catch (e) {
      debugPrint('[Auth] Error completing onboarding: $e');
    }
  }

  Future<void> logout() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_kUserKey);
    try {
      await FirebaseService.auth.signOut();
    } catch (_) {}
    state = AuthState();
  }

  Future<User?> _loadUserFromFirestore({required String uid}) async {
    final snap = await FirebaseService.firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return User.fromJson({'id': uid, ...data});
  }

  Future<void> _saveUserToFirestore({required String uid, required User user}) {
    return FirebaseService.firestore.collection('users').doc(uid).set({
      ...user.toJson(),
      // Ensure role always persists as string.
      'role': user.role.name,
    }, SetOptions(merge: true));
  }

  Future<User?> _loginWithFirebase(String email, String password) async {
    if (!FirebaseService.isInitialized) return null;

    try {
      final cred = await FirebaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception('Login failed');
      }

      final fromDb = await _loadUserFromFirestore(uid: uid);
      if (fromDb != null) return fromDb;

      // If user exists in Auth but not in Firestore, default them to owner.
      final fallback = User(
        id: uid,
        email: email,
        password: '',
        name: email.split('@').first,
        role: UserRole.owner,
        phone: null,
        address: null,
        factoryId: 'FAC_00001',
      );
      await _saveUserToFirestore(uid: uid, user: fallback);
      return fallback;
    } on fb.FirebaseAuthException catch (e) {
      // If Firebase isn't configured or user isn't found, return null so local fallback can try.
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-email') {
        throw Exception('Invalid email or password');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User> _loginWithLocalFallback(String email, String password) async {
    // Simulate small delay for parity with previous UX.
    await Future.delayed(const Duration(milliseconds: 350));

    final local = await _getLocalUsers();
    final user = [...local, ...hardcodedUsers].firstWhere(
      (u) => u.email.toLowerCase() == email && u.password == password,
      orElse: () => throw Exception('Invalid email or password'),
    );

    // Never persist password in authenticated state.
    return User(
      id: user.id,
      email: user.email,
      password: '',
      name: user.name,
      role: user.role,
      phone: user.phone,
      address: user.address,
      avatar: user.avatar,
      factoryId: user.factoryId,
      linkedEntityId: user.linkedEntityId,
    );
  }

  Future<User?> _registerWithFirebase({
    required String name,
    required String email,
    required String password,
    required String factoryName,
    required String? phone,
  }) async {
    if (!FirebaseService.isInitialized) return null;

    try {
      // Ensure we don't accidentally "upgrade" an anonymous session in a weird state.
      if (FirebaseService.auth.currentUser?.isAnonymous == true) {
        await FirebaseService.auth.signOut();
      }

      final cred = await FirebaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception('Registration failed');
      }

      // 1. Create the Factory first
      final factoryId = 'FAC_${_uuid.v4().substring(0, 8).toUpperCase()}';
      await FirebaseService.firestore
          .collection('factories')
          .doc(factoryId)
          .set({
            'id': factoryId,
            'name': factoryName,
            'ownerId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 2. Create the Owner entity
      final ownerId = 'OWN_${_uuid.v4().substring(0, 8).toUpperCase()}';
      await FirebaseService.firestore.collection('owners').doc(ownerId).set({
        'id': ownerId,
        'name': name,
        'email': email,
        'phone': phone,
        'factoryId': factoryId,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final user = User(
        id: uid,
        email: email,
        password: '',
        name: name,
        role: UserRole.owner,
        phone: phone,
        address: null,
        factoryId: factoryId,
        linkedEntityId: ownerId,
      );

      await _saveUserToFirestore(uid: uid, user: user);
      return user;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Email is already in use');
      }
      if (e.code == 'invalid-email') {
        throw Exception('Invalid email');
      }
      if (e.code == 'weak-password') {
        throw Exception('Password is too weak');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User> _registerWithLocalFallback({
    required String name,
    required String email,
    required String password,
    required String factoryName,
    required String? phone,
  }) async {
    final users = await _getLocalUsers();
    final exists = users.any(
      (u) => u.email.toLowerCase().trim() == email.trim(),
    );
    if (exists) {
      throw Exception('Email is already in use');
    }

    final factoryId = 'FAC_${_uuid.v4().substring(0, 8).toUpperCase()}';
    final ownerId = 'OWN_${_uuid.v4().substring(0, 8).toUpperCase()}';

    final id = 'USR_${_uuid.v4().substring(0, 8).toUpperCase()}';
    final user = User(
      id: id,
      email: email,
      password: password, // stored only for local fallback login
      name: name,
      role: UserRole.owner,
      phone: phone,
      address: null,
      factoryId: factoryId,
      linkedEntityId: ownerId,
    );

    await _saveLocalUsers([...users, user]);

    // Never persist password in authenticated state.
    return User(
      id: user.id,
      email: user.email,
      password: '',
      name: user.name,
      role: user.role,
      phone: user.phone,
      address: user.address,
      avatar: user.avatar,
      factoryId: user.factoryId,
      linkedEntityId: user.linkedEntityId,
    );
  }

  Future<List<User>> _getLocalUsers() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kLocalUsersKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => User.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalUsers(List<User> users) async {
    _prefs ??= await SharedPreferences.getInstance();
    final payload = users
        .map(
          (u) => {
            ...u.toJson(),
            // local fallback stores password for login parity only
            'password': u.password,
          },
        )
        .toList();
    await _prefs!.setString(_kLocalUsersKey, jsonEncode(payload));
  }
}

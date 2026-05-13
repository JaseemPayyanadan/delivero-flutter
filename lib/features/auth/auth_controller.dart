import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/firebase_service.dart';
import '../../data/models/driver.dart';
import '../../data/models/user.dart';

/// Authentication state for the phone + OTP flow.
///
/// `user` is set after we have a Firestore profile (`users/{uid}`). For new
/// owner sign-ups a minimal profile is auto-created right after OTP — the
/// onboarding wizard then collects the business name and other details.
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  /// OTP that has been requested but not yet verified.
  final String? pendingPhone;
  final String? verificationId;
  final int? resendToken;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.pendingPhone,
    this.verificationId,
    this.resendToken,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    Object? error = _sentinel,
    Object? pendingPhone = _sentinel,
    Object? verificationId = _sentinel,
    Object? resendToken = _sentinel,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      pendingPhone: pendingPhone == _sentinel
          ? this.pendingPhone
          : pendingPhone as String?,
      verificationId: verificationId == _sentinel
          ? this.verificationId
          : verificationId as String?,
      resendToken: resendToken == _sentinel
          ? this.resendToken
          : resendToken as int?,
    );
  }

  AuthState withClearedUser() {
    return const AuthState();
  }

  static const _sentinel = Object();
}

class AuthNotifier extends Notifier<AuthState> {
  static const _kUserKey = 'auth_user';
  SharedPreferences? _prefs;
  final _uuid = const Uuid();

  /// Web-only handle to the active phone-auth confirmation flow. On mobile we
  /// store the verification id on the state instead and rebuild the credential
  /// in [verifyOtp].
  fb.ConfirmationResult? _webConfirmation;

  @override
  AuthState build() {
    return const AuthState();
  }

  Future<void> init() async {
    debugPrint('[Auth] Initializing...');
    _prefs ??= await SharedPreferences.getInstance();

    if (!FirebaseService.isInitialized) {
      debugPrint('[Auth] Firebase not initialised; skipping session restore.');
      return;
    }

    try {
      final current = FirebaseService.auth.currentUser;
      if (current != null && current.phoneNumber != null) {
        final user = await _loadUserFromFirestore(uid: current.uid);
        if (user != null) {
          debugPrint('[Auth] Loaded Firebase user: ${user.phone}');
          state = state.copyWith(user: user);
          await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
          return;
        }
        // Verified phone but no profile doc → auto-create a minimal owner
        // profile. The onboarding wizard will then collect the rest.
        await _autoCreateOwnerProfile(
          uid: current.uid,
          phone: current.phoneNumber!,
        );
        return;
      }
    } catch (e) {
      debugPrint('[Auth] Firebase session load skipped: $e');
    }

    final userJson = _prefs!.getString(_kUserKey);
    if (userJson != null) {
      try {
        final user = User.fromJson(jsonDecode(userJson));
        debugPrint('[Auth] Loaded cached user: ${user.phone}');
        state = state.copyWith(user: user);
      } catch (e) {
        debugPrint('[Auth] Error loading cached user: $e');
        await _prefs!.remove(_kUserKey);
      }
    }
  }

  /// Sends an OTP to [phoneE164] (must already be in `+CCNNNNNNNNNN` form).
  ///
  /// Stores `verificationId` in state on success so the OTP screen can call
  /// [verifyOtp]. On Android, [verificationCompleted] may auto-sign-in. On
  /// web, [signInWithPhoneNumber] is used because [verifyPhoneNumber] is not
  /// supported there.
  Future<void> sendOtp(String phoneE164, {bool forceResend = false}) async {
    if (!FirebaseService.isInitialized) {
      state = state.copyWith(
        error: 'Firebase is not configured.',
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      pendingPhone: phoneE164,
    );

    if (kIsWeb) {
      try {
        final platformAuth = FirebaseAuthPlatform.instanceFor(
          app: FirebaseService.auth.app,
          pluginConstants: FirebaseService.auth.pluginConstants,
        );
        final verifier = fb.RecaptchaVerifier(auth: platformAuth);
        _webConfirmation = await FirebaseService.auth.signInWithPhoneNumber(
          phoneE164,
          verifier,
        );
        state = state.copyWith(
          isLoading: false,
          verificationId: _webConfirmation!.verificationId,
        );
      } on fb.FirebaseAuthException catch (e) {
        debugPrint('[Auth] signInWithPhoneNumber failed: ${e.code}');
        _webConfirmation = null;
        state = state.copyWith(isLoading: false, error: _humanizePhoneError(e));
      } catch (e) {
        debugPrint('[Auth] signInWithPhoneNumber error: $e');
        _webConfirmation = null;
        state = state.copyWith(
          isLoading: false,
          error: 'Could not send OTP. Please try again.',
        );
      }
      return;
    }

    final completer = Completer<void>();

    try {
      await FirebaseService.auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        forceResendingToken: forceResend ? state.resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          try {
            final cred = await FirebaseService.auth.signInWithCredential(
              credential,
            );
            final uid = cred.user?.uid;
            if (uid != null) {
              await _completeSignIn(uid: uid, phone: phoneE164);
            }
          } catch (e) {
            debugPrint('[Auth] Auto verification failed: $e');
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          debugPrint('[Auth] verifyPhoneNumber failed: ${e.code} ${e.message}');
          state = state.copyWith(
            isLoading: false,
            error: _humanizePhoneError(e),
          );
          if (!completer.isCompleted) completer.complete();
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
          );
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Keep the verification id around for manual entry after auto-retrieval times out.
          state = state.copyWith(verificationId: verificationId);
        },
      );
      await completer.future;
    } catch (e) {
      debugPrint('[Auth] sendOtp error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not send OTP. Please try again.',
      );
    }
  }

  /// Verifies the user-entered [smsCode] against the stored verification id.
  Future<void> verifyOtp(String smsCode) async {
    final phone = state.pendingPhone;
    if (phone == null) {
      state = state.copyWith(
        error: 'OTP session expired. Please request a new code.',
      );
      return;
    }
    if (!kIsWeb && state.verificationId == null) {
      state = state.copyWith(
        error: 'OTP session expired. Please request a new code.',
      );
      return;
    }
    if (kIsWeb && _webConfirmation == null) {
      state = state.copyWith(
        error: 'OTP session expired. Please request a new code.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final fb.UserCredential cred;
      if (kIsWeb) {
        cred = await _webConfirmation!.confirm(smsCode);
        _webConfirmation = null;
      } else {
        final credential = fb.PhoneAuthProvider.credential(
          verificationId: state.verificationId!,
          smsCode: smsCode,
        );
        cred = await FirebaseService.auth.signInWithCredential(credential);
      }
      final uid = cred.user?.uid;
      if (uid == null) {
        throw Exception('Sign-in failed. Please try again.');
      }
      await _completeSignIn(uid: uid, phone: phone);
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('[Auth] verifyOtp failed: ${e.code} ${e.message}');
      state = state.copyWith(isLoading: false, error: _humanizeOtpError(e));
    } catch (e) {
      debugPrint('[Auth] verifyOtp error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Verification failed',
      );
    }
  }

  /// Called after successful Firebase phone sign-in. Loads/creates the
  /// Firestore profile and routes the user to the correct shell:
  ///
  /// 1. If `users/{uid}` exists → set state.user and we're done.
  /// 2. Else if a pending driver matches the phone → auto-link as delivery.
  /// 3. Else → auto-create a minimal owner profile; onboarding fills the rest.
  Future<void> _completeSignIn({
    required String uid,
    required String phone,
  }) async {
    try {
      final existing = await _loadUserFromFirestore(uid: uid);
      if (existing != null) {
        await _persistSession(existing);
        state = AuthState(user: existing);
        return;
      }

      final linked = await _tryAutoLinkDriver(uid: uid, phone: phone);
      if (linked != null) {
        await _persistSession(linked);
        state = AuthState(user: linked);
        return;
      }

      await _autoCreateOwnerProfile(uid: uid, phone: phone);
    } catch (e) {
      debugPrint('[Auth] _completeSignIn error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your profile. Please try again.',
      );
    }
  }

  /// Looks for a pending driver whose phone matches [phone]. If found,
  /// transactionally links the Firebase UID and creates the `users/{uid}` doc.
  Future<User?> _tryAutoLinkDriver({
    required String uid,
    required String phone,
  }) async {
    final snapshot = await FirebaseService.firestore
        .collection('drivers')
        .where('phone', isEqualTo: phone)
        .limit(5)
        .get();

    final pending = snapshot.docs.firstWhereOrNull((doc) {
      final data = doc.data();
      final status = (data['status'] as String?) ?? 'pending';
      final existingUserId = data['userId'] as String?;
      return status == 'pending' &&
          (existingUserId == null || existingUserId.isEmpty);
    });
    if (pending == null) return null;

    final driverData = pending.data();
    final driverId = pending.id;
    final factoryId = driverData['factoryId'] as String? ?? '';
    final driverName = driverData['name'] as String? ?? '';

    final user = User(
      id: uid,
      phone: phone,
      name: driverName,
      role: UserRole.delivery,
      factoryId: factoryId,
      linkedEntityId: driverId,
    );

    final batch = FirebaseService.firestore.batch();
    batch.set(
      FirebaseService.firestore.collection('users').doc(uid),
      {...user.toJson(), 'role': user.role.name},
      SetOptions(merge: true),
    );
    batch
        .update(FirebaseService.firestore.collection('drivers').doc(driverId), {
          'userId': uid,
          'isActive': true,
          'status': DriverStatus.active.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await batch.commit();
    return user;
  }

  /// Creates a minimal owner + factory + user record after a brand-new
  /// phone sign-in. Names are intentionally left empty — the onboarding
  /// wizard collects the business name (which is merged into the factory
  /// doc) and the user can update their personal name in settings.
  Future<void> _autoCreateOwnerProfile({
    required String uid,
    required String phone,
  }) async {
    try {
      final factoryId = 'FAC_${_uuid.v4().substring(0, 8).toUpperCase()}';
      final ownerId = 'OWN_${_uuid.v4().substring(0, 8).toUpperCase()}';

      final batch = FirebaseService.firestore.batch();
      batch.set(
        FirebaseService.firestore.collection('factories').doc(factoryId),
        {
          'id': factoryId,
          'name': '',
          'ownerId': uid,
          'plan': SubscriptionPlan.free.name,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(FirebaseService.firestore.collection('owners').doc(ownerId), {
        'id': ownerId,
        'name': '',
        'phone': phone,
        'factoryId': factoryId,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final user = User(
        id: uid,
        phone: phone,
        name: '',
        role: UserRole.owner,
        plan: SubscriptionPlan.free,
        factoryId: factoryId,
        linkedEntityId: ownerId,
      );

      batch.set(
        FirebaseService.firestore.collection('users').doc(uid),
        {...user.toJson(), 'role': user.role.name},
        SetOptions(merge: true),
      );
      await batch.commit();

      await _persistSession(user);
      state = AuthState(user: user);
    } catch (e) {
      debugPrint('[Auth] _autoCreateOwnerProfile error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not create your account. Please try again.',
      );
    }
  }

  /// Creates a pending driver entity. The driver becomes "active" the first
  /// time they sign in with phone + OTP (auto-linking).
  Future<Driver> inviteDriver({
    required String name,
    required String phoneE164,
    required String factoryId,
    required VehicleType vehicleType,
    String? currentRoute,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final driver = Driver(
      id: id,
      factoryId: factoryId,
      name: name,
      phone: phoneE164,
      vehicleType: vehicleType,
      isActive: false,
      currentRoute: currentRoute,
      createdAt: now,
      updatedAt: now,
      status: DriverStatus.pending,
    );

    await FirebaseService.firestore
        .collection('drivers')
        .doc(id)
        .set(driver.toJson());
    return driver;
  }

  /// Updates the signed-in user's display name. Writes to `users/{uid}` and,
  /// for owners, the linked `owners/{ownerId}` doc. Mirrors the change into
  /// local state + the cached session so the dashboard sees it instantly.
  Future<void> updateOwnerName(String name) async {
    final user = state.user;
    if (user == null) return;

    final trimmed = name.trim();
    if (trimmed == user.name.trim()) return;

    final updated = user.copyWith(name: trimmed);

    try {
      if (FirebaseService.isInitialized) {
        final batch = FirebaseService.firestore.batch();
        batch.set(
          FirebaseService.firestore.collection('users').doc(user.id),
          {
            'name': trimmed,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final linkedId = user.linkedEntityId;
        if (linkedId != null && linkedId.trim().isNotEmpty) {
          final collection =
              user.role == UserRole.owner ? 'owners' : 'drivers';
          batch.set(
            FirebaseService.firestore.collection(collection).doc(linkedId),
            {
              'name': trimmed,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }

      await _persistSession(updated);
      state = state.copyWith(user: updated);
    } catch (e) {
      debugPrint('[Auth] updateOwnerName error: $e');
      rethrow;
    }
  }

  Future<void> completeOnboarding() async {
    if (state.user == null) return;

    final updated = state.user!.copyWith(hasFinishedOnboarding: true);
    try {
      if (FirebaseService.isInitialized) {
        await _saveUserToFirestore(uid: state.user!.id, user: updated);
      }
      await _persistSession(updated);
      state = state.copyWith(user: updated);
      debugPrint('[Auth] Onboarding completed for ${updated.phone}');
    } catch (e) {
      debugPrint('[Auth] Error completing onboarding: $e');
    }
  }

  Future<void> logout() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_kUserKey);
    _webConfirmation = null;
    try {
      await FirebaseService.auth.signOut();
    } catch (_) {}
    state = const AuthState();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  void cancelPendingOtp() {
    _webConfirmation = null;
    state = state.copyWith(
      verificationId: null,
      pendingPhone: null,
      resendToken: null,
      error: null,
      isLoading: false,
    );
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
      'role': user.role.name,
    }, SetOptions(merge: true));
  }

  Future<void> _persistSession(User user) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_kUserKey, jsonEncode(user.toJson()));
  }

  String _humanizePhoneError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid. Check the country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return e.message ?? 'Could not send OTP.';
    }
  }

  String _humanizeOtpError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'That code is incorrect. Please try again.';
      case 'session-expired':
      case 'code-expired':
        return 'Code expired. Please request a new one.';
      default:
        return e.message ?? 'Verification failed.';
    }
  }
}

extension _FirstWhereOrNullDocs<T>
    on List<QueryDocumentSnapshot<Map<String, dynamic>>> {
  QueryDocumentSnapshot<Map<String, dynamic>>? firstWhereOrNull(
    bool Function(QueryDocumentSnapshot<Map<String, dynamic>>) test,
  ) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

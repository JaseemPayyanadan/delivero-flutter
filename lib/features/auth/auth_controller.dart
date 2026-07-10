import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final bool isInitialized;
  final bool isLoading;
  final String? error;

  /// OTP that has been requested but not yet verified.
  final String? pendingPhone;
  final String? verificationId;
  final int? resendToken;

  const AuthState({
    this.user,
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.pendingPhone,
    this.verificationId,
    this.resendToken,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isInitialized,
    bool? isLoading,
    Object? error = _sentinel,
    Object? pendingPhone = _sentinel,
    Object? verificationId = _sentinel,
    Object? resendToken = _sentinel,
  }) {
    return AuthState(
      user: user ?? this.user,
      isInitialized: isInitialized ?? this.isInitialized,
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
    return const AuthState(isInitialized: true);
  }

  static const _sentinel = Object();
}

class AuthNotifier extends Notifier<AuthState> {
  static const _kUserKey = 'auth_user';
  static const _kVerificationIdKey = 'auth_verification_id';
  static const _kLastAuthAtKey = 'auth_last_authenticated_at';
  static const _sessionMaxAge = Duration(days: 90);
  static const _secureStorage = FlutterSecureStorage();
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

    if (!FirebaseService.isInitialized) {
      debugPrint('[Auth] Firebase not initialised; skipping session restore.');
      state = state.copyWith(isInitialized: true);
      return;
    }

    try {
      final current = FirebaseService.auth.currentUser;
      if (current != null && current.phoneNumber != null) {
        if (await _isSessionExpired()) {
          debugPrint('[Auth] Session older than 90 days; requiring re-login.');
          await _clearStoredSession(signOutFirebase: true);
          state = state.copyWith(isInitialized: true);
          return;
        }

        final user = await _loadUserFromFirestore(uid: current.uid);
        if (user != null) {
          debugPrint('[Auth] Loaded Firebase user: ${user.phone}');
          await _persistSession(user);
          state = state.copyWith(user: user, isInitialized: true);
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

    final userJson = await _secureStorage.read(key: _kUserKey);
    if (userJson != null) {
      if (await _isSessionExpired()) {
        debugPrint(
          '[Auth] Cached session older than 90 days; requiring re-login.',
        );
        await _clearStoredSession(signOutFirebase: true);
        state = state.copyWith(isInitialized: true);
        return;
      }

      try {
        final user = User.fromJson(jsonDecode(userJson));
        debugPrint('[Auth] Loaded cached user: ${user.phone}');
        state = state.copyWith(user: user, isInitialized: true);
      } catch (e) {
        debugPrint('[Auth] Error loading cached user: $e');
        await _secureStorage.delete(key: _kUserKey);
        await _secureStorage.delete(key: _kLastAuthAtKey);
      }
    }
    state = state.copyWith(isInitialized: true);
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
          _saveVerificationId(verificationId);
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
          );
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _saveVerificationId(verificationId);
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
      // C4: try to restore verificationId that survived an app kill
      final stored = await _secureStorage.read(key: _kVerificationIdKey);
      if (stored == null) {
        state = state.copyWith(
          error: 'OTP session expired. Please request a new code.',
        );
        return;
      }
      state = state.copyWith(verificationId: stored);
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
  /// 3. Else if an existing owner matches the phone → re-link to that owner's
  ///    factory (prevents spawning a duplicate factory for a returning owner).
  /// 4. Else → auto-create a minimal owner profile; onboarding fills the rest.
  Future<void> _completeSignIn({
    required String uid,
    required String phone,
  }) async {
    try {
      final existing = await _loadUserFromFirestore(uid: uid);
      if (existing != null) {
        await _persistSession(existing);
        state = AuthState(user: existing, isInitialized: true);
        return;
      }

      final linked = await _tryAutoLinkDriver(uid: uid, phone: phone);
      if (linked != null) {
        await _persistSession(linked);
        state = AuthState(user: linked, isInitialized: true);
        return;
      }

      final owner = await _tryAutoLinkOwner(uid: uid, phone: phone);
      if (owner != null) {
        await _persistSession(owner);
        state = AuthState(user: owner, isInitialized: true);
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
    final driversRef = FirebaseService.firestore.collection('drivers');
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    var snapshot = await driversRef
        .where('phone', isEqualTo: phone)
        .limit(5)
        .get();
    if (snapshot.docs.isEmpty && digits.isNotEmpty) {
      snapshot = await driversRef
          .where('phoneDigits', isEqualTo: digits)
          .limit(5)
          .get();
    }

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

  /// Looks for an existing owner whose phone matches [phone]. If found, links
  /// the current Firebase UID to that owner's factory and writes the
  /// `users/{uid}` doc — so a returning owner (whose account was created out of
  /// band, e.g. via the admin panel or a prior UID) reuses their existing
  /// factory instead of `_autoCreateOwnerProfile` minting a brand-new one.
  ///
  /// Owner docs are historically stored with varying phone formats (E.164,
  /// digits only, or the national number), so we match against a small set of
  /// candidate representations rather than a single exact string.
  Future<User?> _tryAutoLinkOwner({
    required String uid,
    required String phone,
  }) async {
    final ownersRef = FirebaseService.firestore.collection('owners');
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    final candidates = <String>{phone};
    if (digits.isNotEmpty) {
      candidates.add(digits);
      if (digits.length > 10) {
        candidates.add(digits.substring(digits.length - 10));
      }
    }

    final snapshot = await ownersRef
        .where('phone', whereIn: candidates.toList())
        .limit(10)
        .get();
    if (snapshot.docs.isEmpty) return null;

    // Prefer an owner not yet linked to a different Firebase UID; phone is the
    // identity under phone-auth, so an unclaimed or self-owned doc is safe to
    // adopt. Skip docs already claimed by a *different* uid to avoid hijacking.
    final match =
        snapshot.docs.firstWhereOrNull((doc) {
          final existingUserId = (doc.data()['userId'] as String?) ?? '';
          return existingUserId.isEmpty || existingUserId == uid;
        }) ??
        snapshot.docs.firstWhereOrNull(
          (doc) => ((doc.data()['userId'] as String?) ?? '').isEmpty,
        );
    if (match == null) return null;

    final ownerData = match.data();
    final ownerId = match.id;
    final factoryId = (ownerData['factoryId'] as String?) ?? '';
    if (factoryId.isEmpty) return null;
    final ownerName = (ownerData['name'] as String?) ?? '';

    final user = User(
      id: uid,
      phone: phone,
      name: ownerName,
      role: UserRole.owner,
      factoryId: factoryId,
      linkedEntityId: ownerId,
    );

    final batch = FirebaseService.firestore.batch();
    batch.set(
      FirebaseService.firestore.collection('users').doc(uid),
      {...user.toJson(), 'role': user.role.name},
      SetOptions(merge: true),
    );
    batch.update(FirebaseService.firestore.collection('owners').doc(ownerId), {
      'userId': uid,
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
      final factoryId = 'FAC_${_uuid.v4().replaceAll('-', '').toUpperCase()}';
      final ownerId = 'OWN_${_uuid.v4().replaceAll('-', '').toUpperCase()}';

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
      state = AuthState(user: user, isInitialized: true);
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
    var driver = Driver(
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

    final driversRef = FirebaseService.firestore.collection('drivers');
    final routesRef = FirebaseService.firestore.collection('routes');

    await FirebaseService.firestore.runTransaction((tx) async {
      if (currentRoute != null && currentRoute.trim().isNotEmpty) {
        final routeRef = routesRef.doc(currentRoute);
        final routeSnap = await tx.get(routeRef);
        if (routeSnap.exists) {
          final data = routeSnap.data();
          final previousDriverId = (data?['assignedDriver'] as String?)?.trim();
          if (previousDriverId != null &&
              previousDriverId.isNotEmpty &&
              previousDriverId != id) {
            tx.update(driversRef.doc(previousDriverId), {
              'currentRoute': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          tx.update(routeRef, {
            'assignedDriver': id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          driver = driver.copyWith(currentRoute: null);
        }
      }

      tx.set(driversRef.doc(id), driver.toJson());
    });
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
          {'name': trimmed, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );

        final linkedId = user.linkedEntityId;
        if (linkedId != null && linkedId.trim().isNotEmpty) {
          final collection = user.role == UserRole.owner ? 'owners' : 'drivers';
          batch.set(
            FirebaseService.firestore.collection(collection).doc(linkedId),
            {'name': trimmed, 'updatedAt': FieldValue.serverTimestamp()},
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
    // C5: delete FCM token so this device stops receiving notifications
    final user = state.user;
    if (user != null) {
      final factoryId = user.factoryId;
      if (factoryId != null && factoryId.isNotEmpty) {
        try {
          await FirebaseService.firestore
              .collection('factories')
              .doc(factoryId)
              .collection('deliveroPushDevices')
              .doc(user.id)
              .delete();
        } catch (e) {
          debugPrint('[FCM] Failed to delete device token on logout: $e');
        }
      }
    }
    await _clearStoredSession(signOutFirebase: true);
    state = const AuthState(isInitialized: true);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  void cancelPendingOtp() {
    _webConfirmation = null;
    _clearVerificationId();
    state = state.copyWith(
      verificationId: null,
      pendingPhone: null,
      resendToken: null,
      error: null,
      isLoading: false,
    );
  }

  void _saveVerificationId(String id) {
    _secureStorage
        .write(key: _kVerificationIdKey, value: id)
        .catchError(
          (Object e) =>
              debugPrint('[Auth] Failed to persist verificationId: $e'),
        );
  }

  void _clearVerificationId() {
    _secureStorage
        .delete(key: _kVerificationIdKey)
        .catchError(
          (Object e) => debugPrint('[Auth] Failed to clear verificationId: $e'),
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
    await _secureStorage.write(
      key: _kUserKey,
      value: jsonEncode(user.toJson()),
    );
    await _secureStorage.write(
      key: _kLastAuthAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    _clearVerificationId();
  }

  Future<bool> _isSessionExpired() async {
    final raw = await _secureStorage.read(key: _kLastAuthAtKey);
    if (raw == null || raw.trim().isEmpty) return false;
    final lastAuth = DateTime.tryParse(raw);
    if (lastAuth == null) return false;
    return DateTime.now().toUtc().difference(lastAuth.toUtc()) > _sessionMaxAge;
  }

  Future<void> _clearStoredSession({required bool signOutFirebase}) async {
    await _secureStorage.delete(key: _kUserKey);
    await _secureStorage.delete(key: _kLastAuthAtKey);
    _clearVerificationId();
    _webConfirmation = null;
    if (signOutFirebase) {
      try {
        await FirebaseService.auth.signOut();
      } catch (_) {}
    }
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

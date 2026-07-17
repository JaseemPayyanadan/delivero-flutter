import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/user.dart';
import 'firebase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }
}

/// Registers FCM, persists tokens for server-side targeting, and shows in-app
/// feedback for foreground notification payloads.
///
/// Server payloads should use notification + data, e.g. types:
/// `order_assigned`, `route_changed`, `payment_pending`.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  GlobalKey<ScaffoldMessengerState>? _messengerKey;
  User? _user;
  bool _configured = false;

  void attachMessenger(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey = key;
  }

  /// Call once after [FirebaseService.init] succeeds on mobile.
  Future<void> configure() async {
    if (kIsWeb || Firebase.apps.isEmpty || _configured) return;
    _configured = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint('[FCM] Opened from notification: ${message.data}');
      }
    });

    messaging.onTokenRefresh.listen((token) {
      final u = _user;
      if (u != null) _persistToken(token, u);
    });
  }

  /// Updates the signed-in user and writes the current FCM token to Firestore.
  Future<void> setUser(User? user) async {
    _user = user;
    if (user == null || kIsWeb || Firebase.apps.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _persistToken(token, user);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] getToken failed: $e');
      }
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    var title = notification?.title ?? message.data['title']?.toString();
    var body = notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) &&
        (body == null || body.isEmpty) &&
        message.data.isNotEmpty) {
      title ??= _titleForDataPayload(message.data);
      body ??= _bodyForDataPayload(message.data);
    }

    title ??= 'Delivro';
    body ??= '';

    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          body.isEmpty ? title : '$title\n$body',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String? _titleForDataPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'order_assigned':
        return 'New order assigned';
      case 'route_changed':
        return 'Route updated';
      case 'payment_pending':
        return 'Payment pending';
      default:
        return 'Delivro';
    }
  }

  static String? _bodyForDataPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final orderId = data['orderId']?.toString();
    final extra = data['message']?.toString();
    if (extra != null && extra.isNotEmpty) return extra;
    switch (type) {
      case 'order_assigned':
        return orderId != null ? 'Order $orderId' : 'You have a new delivery.';
      case 'route_changed':
        return orderId != null
            ? 'Order $orderId — check your route.'
            : 'Your route was updated.';
      case 'payment_pending':
        return orderId != null
            ? 'Order $orderId needs payment.'
            : 'An order needs payment.';
      default:
        return null;
    }
  }

  Future<void> _persistToken(String token, User user) async {
    try {
      final factoryId = user.factoryId;
      if (factoryId == null) {
        debugPrint('[FCM] Skipping token persist: user has no factoryId');
        return;
      }
      await FirebaseService.firestore
          .collection('factories')
          .doc(factoryId)
          .collection('deliveroPushDevices')
          .doc(user.id)
          .set({
            'fcmToken': token,
            'phone': user.phone,
            'role': user.role.name,
            'linkedEntityId': user.linkedEntityId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[FCM] Token saved for ${user.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Token persist failed: $e');
      }
    }
  }
}

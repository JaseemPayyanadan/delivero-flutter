import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> init() async {
    // Check if already initialized
    if (Firebase.apps.isNotEmpty) {
      if (kDebugMode) {
        print('[Firebase] Already initialized');
      }
      return;
    }

    final FirebaseOptions? webOptions = kIsWeb
        ? FirebaseOptions(
            apiKey: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
            authDomain: const String.fromEnvironment(
              'FIREBASE_WEB_AUTH_DOMAIN',
            ),
            projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
            storageBucket: const String.fromEnvironment(
              'FIREBASE_STORAGE_BUCKET',
            ),
            messagingSenderId: const String.fromEnvironment(
              'FIREBASE_MESSAGING_SENDER_ID',
            ),
            appId: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
            measurementId: const String.fromEnvironment(
              'FIREBASE_WEB_MEASUREMENT_ID',
            ),
          )
        : null;

    if (kIsWeb) {
      final o = webOptions!;
      if (o.apiKey.isEmpty || o.projectId.isEmpty || o.appId.isEmpty) {
        throw FlutterError(
          'Missing Firebase web config. Provide --dart-define values for FIREBASE_WEB_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_WEB_APP_ID.',
        );
      }
    }

    await Firebase.initializeApp(options: webOptions);

    if (kDebugMode) {
      print('[Firebase] Initialized successfully');
    }
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_web_options.dart';

class FirebaseService {
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<void> init() async {
    // Check if already initialized
    if (Firebase.apps.isNotEmpty) {
      if (kDebugMode) {
        print('[Firebase] Already initialized');
      }
      return;
    }

    if (kIsWeb) {
      var webOptions = FirebaseOptions(
        apiKey: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
        authDomain: const String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
        projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
        storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        messagingSenderId: const String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        appId: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
        measurementId: const String.fromEnvironment(
          'FIREBASE_WEB_MEASUREMENT_ID',
        ),
      );

      if (webOptions.apiKey.isEmpty ||
          webOptions.projectId.isEmpty ||
          webOptions.appId.isEmpty) {
        final fromWindow = FirebaseWebOptions.tryGetFromWindow();
        if (fromWindow != null) {
          webOptions = fromWindow;
        } else {
          if (kDebugMode) {
            print(
              '[Firebase] Web not configured. Provide --dart-define FIREBASE_WEB_* '
              'or set window.firebaseConfig in web/index.html',
            );
          }
          return;
        }
      }

      await Firebase.initializeApp(options: webOptions);
    } else {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        if (kDebugMode) {
          print('[Firebase] Skipped ($e)');
        }
        return;
      }
    }

    if (kDebugMode) {
      print('[Firebase] Initialized successfully');
    }

    // L7: enable offline persistence so the app works with intermittent connectivity
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
}

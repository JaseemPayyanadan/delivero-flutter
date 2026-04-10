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

    if (kIsWeb) {
      final webOptions = FirebaseOptions(
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
        if (kDebugMode) {
          print('[Firebase] Skipped (missing web config)');
        }
        return;
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

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      if (kDebugMode) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        print('[FirebaseAuth] Signed in${uid == null ? '' : ' ($uid)'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseAuth] Sign-in skipped ($e)');
      }
    }
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
}

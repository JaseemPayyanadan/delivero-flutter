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

    // Manual initialization for development based on .env.local
    // In production, use flutterfire configure to generate firebase_options.dart
    // Note: On Android, if google-services.json is present, it will initialize automatically.
    const webOptions = FirebaseOptions(
      apiKey: 'AIzaSyBtd6op8KUKyAhyHor_3kM4sOvYwkBIe4M',
      authDomain: 'delivero-48322.firebaseapp.com',
      projectId: 'delivero-48322',
      storageBucket: 'delivero-48322.firebasestorage.app',
      messagingSenderId: '246967732090',
      appId: '1:246967732090:web:7ad49c8e94ee32584e38c3',
      measurementId: 'G-TG2E932BCK',
    );

    await Firebase.initializeApp(
      options: kIsWeb
          ? webOptions
          : defaultTargetPlatform == TargetPlatform.android
              ? null
              : webOptions,
    );

    if (kDebugMode) {
      print('[Firebase] Initialized successfully');
    }
  }

  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
}

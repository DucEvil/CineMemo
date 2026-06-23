import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/firebase_options.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.firebaseReady,
    required this.localStorageReady,
  });

  final bool firebaseReady;
  final bool localStorageReady;
}

class AppBootstrap {
  static Future<AppBootstrapResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final firebaseReady = await _initializeFirebase();
    final localStorageReady = await _initializeLocalStorage();

    return AppBootstrapResult(
      firebaseReady: firebaseReady,
      localStorageReady: localStorageReady,
    );
  }

  static Future<bool> _initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (error) {
      // Log but don't crash - app can work with limited functionality
      // ignore: avoid_print
      print('Firebase initialization warning: $error');
      return false;
    }
  }

  static Future<bool> _initializeLocalStorage() async {
    try {
      await Hive.initFlutter();
      return true;
    } catch (_) {
      return false;
    }
  }
}

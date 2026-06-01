import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return windows;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcNEN6xgPhd3GzY6tO6X7yDLG5g-Yk0Hw',
    appId: '1:150666245622:android:43a5b0781a99635d0343d7',
    messagingSenderId: '150666245622',
    projectId: 'cinememo-app',
    storageBucket: 'cinememo-app.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDylzFKpoE8CjsgVyJE72NS94GqP4Fe8ZI',
    appId: '1:150666245622:web:ca0857c1fbd16b740343d7',
    messagingSenderId: '150666245622',
    projectId: 'cinememo-app',
    authDomain: 'cinememo-app.firebaseapp.com',
    storageBucket: 'cinememo-app.firebasestorage.app',
    measurementId: 'G-TR93NELC87',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDylzFKpoE8CjsgVyJE72NS94GqP4Fe8ZI',
    appId: '1:150666245622:web:fb363a7b07ddaa410343d7',
    messagingSenderId: '150666245622',
    projectId: 'cinememo-app',
    authDomain: 'cinememo-app.firebaseapp.com',
    storageBucket: 'cinememo-app.firebasestorage.app',
    measurementId: 'G-WWXT10S20Q',
  );

}
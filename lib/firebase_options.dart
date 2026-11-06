// File generated from local Firebase config files. Do not edit keys by hand.
import "package:firebase_core/firebase_core.dart" show FirebaseOptions;
import "package:flutter/foundation.dart"
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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          "DefaultFirebaseOptions are not supported for this platform.",
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyB--D_UQ3c1CCPrkiFmwcmuL13-8HYX_NE",
      authDomain: "pitchiq-bets.firebaseapp.com",
      projectId: "pitchiq-bets",
      storageBucket: "pitchiq-bets.firebasestorage.app",
      messagingSenderId: "811378565824",
      appId: "1:811378565824:web:f1a92779ebc48cf3b30325",
      measurementId: "G-5HK2N91ES8"
  );

  static const FirebaseOptions android = FirebaseOptions(
      apiKey: "AIzaSyB--D_UQ3c1CCPrkiFmwcmuL13-8HYX_NE",
      authDomain: "pitchiq-bets.firebaseapp.com",
      projectId: "pitchiq-bets",
      storageBucket: "pitchiq-bets.firebasestorage.app",
      messagingSenderId: "811378565824",
      appId: "1:811378565824:web:f1a92779ebc48cf3b30325",
      measurementId: "G-5HK2N91ES8"
  );

  static const FirebaseOptions ios = FirebaseOptions(
      apiKey: "AIzaSyDrOvsLCLP75TLSnaJzsbJUIhpJk5kTIhE",
      authDomain: "pitchiq-bets.firebaseapp.com",
      projectId: "pitchiq-bets",
      storageBucket: "pitchiq-bets.firebasestorage.app",
      messagingSenderId: "811378565824",
      appId: "1:811378565824:ios:2109f1b2acef3738b30325",
      iosBundleId: "com.goal.vantage"
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = web;
  static const FirebaseOptions linux = web;
}

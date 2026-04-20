import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only configured for web in this MVP.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCLvcqWcVQPGiWd1nbTRaNYdev3PHV9vgU',
    appId: '1:688341623906:web:3846901286050617c19d3b',
    messagingSenderId: '688341623906',
    projectId: 'test-mvp-app-caec3',
    authDomain: 'test-mvp-app-caec3.firebaseapp.com',
    storageBucket: 'test-mvp-app-caec3.firebasestorage.app',
    measurementId: 'G-D5PLYTWJ9N',
  );
}

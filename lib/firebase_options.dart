import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Generado manualmente desde google-services.json
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for mac - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBubrqH9EdgOgGzycjycMVs5Y5oF88kpPg',
    appId: '1:179031827037:android:a85300f4226203d031e3b4',
    messagingSenderId: '179031827037',
    projectId: 'demeter-488721-d542f',
    storageBucket: 'demeter-488721-d542f.firebasestorage.app',
  );
}

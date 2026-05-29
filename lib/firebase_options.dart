// Generado via flutterfire configure — proyecto-app-negocio

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web no soportado.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma no soportada.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsSRgZPpB8OCktijPWGstPfHyVsYhn3FU',
    appId: '1:754528680855:android:d11a8e9698c3fa7d3462d2',
    messagingSenderId: '754528680855',
    projectId: 'proyecto-app-negocio',
    storageBucket: 'proyecto-app-negocio.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBjhSPEm44aHWaGyo2tjHY-mcjGORR5yE8',
    appId: '1:754528680855:ios:2686fd7af58879663462d2',
    messagingSenderId: '754528680855',
    projectId: 'proyecto-app-negocio',
    storageBucket: 'proyecto-app-negocio.firebasestorage.app',
    iosBundleId: 'com.negocio.negocioApp',
  );
}

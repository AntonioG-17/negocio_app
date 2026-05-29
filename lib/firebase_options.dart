// ARCHIVO PLACEHOLDER — Reemplazar ejecutando:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// Ver docs/firebase-setup.md para instrucciones detalladas.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      'Firebase no esta configurado.\n'
      'Ejecuta: flutterfire configure\n'
      'Ver docs/firebase-setup.md para instrucciones.',
    );
  }
}

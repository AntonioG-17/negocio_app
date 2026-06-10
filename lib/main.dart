import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/app.dart';
import 'package:negocio_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistencia offline: Firestore sirve datos del caché local cuando no hay
  // internet o la conexión es lenta, y sincroniza en cuanto vuelve la red.
  // Envuelto en try-catch por si el navegador bloquea IndexedDB (modo privado).
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (_) {}

  runApp(const ProviderScope(child: NegocioApp()));
}

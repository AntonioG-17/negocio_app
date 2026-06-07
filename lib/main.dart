import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/app.dart';
import 'package:negocio_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistencia offline: Firestore guarda datos localmente y sincroniza al
  // recuperar conexión. Esencial para un negocio que puede tener mala señal.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Firebase Performance Monitoring — gratuito, sin límite de eventos.
  // Registra tiempos de carga, llamadas a Firestore y errores de red
  // automáticamente. Ver en Firebase Console → Performance.
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  // Orientación fija: portrait only (app de negocio, no necesita landscape).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: NegocioApp()));
}

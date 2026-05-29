import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/models/business_model.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/firebase_options.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final selectedBusinessProvider = StateProvider<Business?>((ref) => null);

// Perfil del usuario actual desde Firestore
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colUsers)
      .doc(user.uid)
      .snapshots()
      .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.role;
});

// Todos los negocios (solo CEO)
final allBusinessesProvider = StreamProvider<List<Business>>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  if (role != UserRole.ceo) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colBusinesses)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Business.fromFirestore).toList());
});

// Trabajadores del negocio actual (solo admin)
final businessWorkersProvider = StreamProvider<List<UserModel>>((ref) {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colUsers)
      .where('businessId', isEqualTo: business.id)
      .where('role', isEqualTo: 'worker')
      .snapshots()
      .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
});

// Legacy: negocios del usuario (para la pantalla de selección)
final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return [];
  final db = ref.watch(firestoreProvider);
  final snap = await db
      .collection(AppConstants.colBusinesses)
      .where('ownerId', isEqualTo: user.uid)
      .get();
  return snap.docs.map(Business.fromFirestore).toList();
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _initUserSession();
    });
  }

  // Inicializa la sesión: crea perfil CEO si aplica, o auto-carga el negocio
  Future<void> _initUserSession() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final profileSnap =
        await _db.collection(AppConstants.colUsers).doc(user.uid).get();

    if (!profileSnap.exists) {
      // Primera vez — si el email es del CEO, crear perfil CEO automáticamente
      if (user.email?.toLowerCase() ==
          AppConstants.ceoEmail.toLowerCase()) {
        await _db.collection(AppConstants.colUsers).doc(user.uid).set({
          'email': user.email,
          'name': 'CEO',
          'role': UserRole.ceo.name,
          'businessId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    final profile = UserModel.fromFirestore(profileSnap);

    // Admin/Worker: auto-cargar su negocio
    if (profile.businessId != null &&
        (profile.role == UserRole.admin || profile.role == UserRole.worker)) {
      final bizSnap = await _db
          .collection(AppConstants.colBusinesses)
          .doc(profile.businessId)
          .get();
      if (bizSnap.exists) {
        ref.read(selectedBusinessProvider.notifier).state =
            Business.fromFirestore(bizSnap);
      }
    }
  }

  // CEO: crea un negocio nuevo + cuenta del admin
  Future<void> createBusinessWithAdmin({
    required String businessName,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bizRef = _db.collection(AppConstants.colBusinesses).doc();
      final uid = await _createFirebaseUser(adminEmail, adminPassword);

      await bizRef.set({
        'name': businessName.trim(),
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection(AppConstants.colUsers).doc(uid).set({
        'email': adminEmail.trim(),
        'name': adminName.trim(),
        'role': UserRole.admin.name,
        'businessId': bizRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Admin: crea cuenta de trabajador para su negocio
  Future<void> createWorker({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = ref.read(selectedBusinessProvider);
      if (business == null) throw Exception('No hay negocio seleccionado');

      final uid = await _createFirebaseUser(email, password);

      await _db.collection(AppConstants.colUsers).doc(uid).set({
        'email': email.trim(),
        'name': name.trim(),
        'role': UserRole.worker.name,
        'businessId': business.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Admin: quita a un trabajador del negocio
  Future<void> removeWorker(String workerId) async {
    await _db.collection(AppConstants.colUsers).doc(workerId).update({
      'businessId': null,
    });
  }

  // Crea cuenta Firebase sin cerrar sesión del usuario actual (app secundaria)
  Future<String> _createFirebaseUser(String email, String password) async {
    final name = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tmp;
    try {
      tmp = await Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final cred = await FirebaseAuth.instanceFor(app: tmp)
          .createUserWithEmailAndPassword(
              email: email.trim(), password: password);
      return cred.user!.uid;
    } finally {
      await tmp?.delete();
    }
  }

  Future<void> logout() async {
    ref.read(selectedBusinessProvider.notifier).state = null;
    await _auth.signOut();
  }

  // Legacy — mantener compatibilidad
  Future<void> createBusiness(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection(AppConstants.colBusinesses).add({
      'name': name.trim(),
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(userBusinessesProvider);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/models/business_model.dart';
import 'package:negocio_app/features/auth/models/membership_model.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/pos/providers/pos_provider.dart';
import 'package:negocio_app/firebase_options.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Negocio activo (el que se está viendo/operando).
final selectedBusinessProvider = StateProvider<Business?>((ref) => null);

// Membresía activa (negocio + rol) del usuario no-CEO. Se setea al elegir un
// negocio. De aquí sale el ROL para ese negocio.
final selectedMembershipProvider = StateProvider<Membership?>((ref) => null);

// Perfil del usuario (nombre/correo). El rol legacy ya no se usa para permisos.
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

// ¿La cuenta es la del CEO? (cuenta especial por correo, ve todos los negocios).
final isCeoEmailProvider = Provider<bool>((ref) {
  final email = ref.watch(authStateProvider).valueOrNull?.email?.toLowerCase();
  return email != null && email == AppConstants.ceoEmail.toLowerCase();
});

// Membresías activas del usuario (por correo). Decide 0 / 1 / 2+ negocios.
// StreamProvider para detectar en tiempo real si el admin desactiva al usuario
// o elimina su membresía — el router los expulsará automáticamente.
final userMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final email = user?.email?.toLowerCase();
  if (email == null) return const Stream.empty();
  if (email == AppConstants.ceoEmail.toLowerCase()) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colMemberships)
      .where('email', isEqualTo: email)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs.map(Membership.fromFirestore).toList());
});

// Negocios para el menú de selección (los de las membresías del usuario).
final userMenuBusinessesProvider =
    FutureProvider<List<({Business business, Membership membership})>>((ref) async {
  final memberships = await ref.watch(userMembershipsProvider.future);
  final db = ref.watch(firestoreProvider);
  final out = <({Business business, Membership membership})>[];
  for (final m in memberships) {
    final snap =
        await db.collection(AppConstants.colBusinesses).doc(m.businessId).get();
    if (snap.exists) {
      out.add((business: Business.fromFirestore(snap), membership: m));
    }
  }
  out.sort((a, b) => a.business.name.compareTo(b.business.name));
  return out;
});

// Rol efectivo: CEO por correo; si no, el rol de la membresía elegida.
final currentUserRoleProvider = Provider<UserRole?>((ref) {
  if (ref.watch(isCeoEmailProvider)) return UserRole.ceo;
  return ref.watch(selectedMembershipProvider)?.role;
});

// CEO viendo un negocio en modo SOLO LECTURA (preview).
final isCeoPreviewProvider = Provider<bool>((ref) {
  return ref.watch(isCeoEmailProvider) &&
      ref.watch(selectedBusinessProvider) != null;
});

// Todos los negocios (solo CEO).
final allBusinessesProvider = StreamProvider<List<Business>>((ref) {
  if (!ref.watch(isCeoEmailProvider)) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colBusinesses)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Business.fromFirestore).toList());
});

// Trabajadores (membresías 'worker') del negocio actual — para el panel de equipo.
final businessWorkersProvider = StreamProvider<List<Membership>>((ref) {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection(AppConstants.colMemberships)
      .where('businessId', isEqualTo: business.id)
      .where('role', isEqualTo: 'worker')
      .snapshots()
      .map((snap) => snap.docs.map(Membership.fromFirestore).toList());
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

  Future<void> sendPasswordReset(String email) async {
    await _auth.setLanguageCode('es');
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
      actionCodeSettings: ActionCodeSettings(
        url: 'https://proyecto-app-negocio.web.app/recuperar',
        handleCodeInApp: true,
      ),
    );
  }

  Future<void> changePassword(String current, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No hay sesión activa');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: current,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  // Inicializa la sesión: crea perfil CEO si aplica, o migra membresía legacy.
  Future<void> _initUserSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email?.toLowerCase();

    // CEO: cuenta especial. Crear su perfil si es la primera vez.
    if (email == AppConstants.ceoEmail.toLowerCase()) {
      final snap =
          await _db.collection(AppConstants.colUsers).doc(user.uid).get();
      if (!snap.exists) {
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

    await _migrateLegacyMembership(user);
    // El router decide 0 / 1 / 2+ según userMembershipsProvider.
    ref.invalidate(userMembershipsProvider);
  }

  // Convierte un perfil legacy (users/{uid}.businessId+role) en una membresía,
  // una sola vez, para no perder las cuentas creadas antes del modelo nuevo.
  Future<void> _migrateLegacyMembership(User user) async {
    final email = user.email!.toLowerCase();
    final existing = await _db
        .collection(AppConstants.colMemberships)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return; // ya tiene membresías

    final profSnap =
        await _db.collection(AppConstants.colUsers).doc(user.uid).get();
    if (!profSnap.exists) return;
    final prof = UserModel.fromFirestore(profSnap);
    if (prof.businessId == null) return;
    if (prof.role != UserRole.admin && prof.role != UserRole.worker) return;

    // Añadir businessId al array del perfil para que las Firestore rules puedan
    // verificar pertenencia sin necesitar Cloud Functions.
    await _db.collection(AppConstants.colUsers).doc(user.uid).update({
      'businessIds': FieldValue.arrayUnion([prof.businessId!]),
    });

    await _db.collection(AppConstants.colMemberships).add(Membership.toMap(
          email: email,
          name: prof.name,
          businessId: prof.businessId!,
          role: prof.role,
          isActive: prof.isActive,
        ));
  }

  // Elige un negocio (membresía) → setea negocio + membresía activos.
  Future<void> selectMembership(Membership m) async {
    final snap =
        await _db.collection(AppConstants.colBusinesses).doc(m.businessId).get();
    if (snap.exists) {
      ref.read(selectedBusinessProvider.notifier).state =
          Business.fromFirestore(snap);
      ref.read(selectedMembershipProvider.notifier).state = m;
    }
  }

  bool _loadingBusiness = false;
  String? _migratedUid;

  // Tras un refresh (sin login): migra la cuenta legacy si hace falta y, si la
  // persona tiene exactamente UNA membresía, entra directo. Con 2+ el router la
  // manda al menú de selección.
  Future<void> loadBusinessForCurrentUser() async {
    if (_loadingBusiness) return;
    if (ref.read(selectedBusinessProvider) != null) return;
    _loadingBusiness = true;
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final isCeo =
          user.email?.toLowerCase() == AppConstants.ceoEmail.toLowerCase();
      if (!isCeo && _migratedUid != user.uid) {
        await _migrateLegacyMembership(user);
        _migratedUid = user.uid;
        ref.invalidate(userMembershipsProvider);
      }
      final memberships = await ref.read(userMembershipsProvider.future);
      if (memberships.length == 1) {
        await selectMembership(memberships.first);
      }
    } finally {
      _loadingBusiness = false;
    }
  }

  // CEO: crea un negocio nuevo + invita a su admin por correo.
  Future<void> createBusinessWithAdmin({
    required String businessName,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bizRef = _db.collection(AppConstants.colBusinesses).doc();
      await bizRef.set({
        'name': businessName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _inviteToBusinessId(
        businessId: bizRef.id,
        name: adminName,
        email: adminEmail,
        role: UserRole.admin,
      );
    });
  }

  // Admin: invita a un trabajador por correo a SU negocio.
  Future<void> inviteWorker({
    required String name,
    required String email,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = ref.read(selectedBusinessProvider);
      if (business == null) throw Exception('No hay negocio seleccionado');
      await _inviteToBusinessId(
        businessId: business.id,
        name: name,
        email: email,
        role: UserRole.worker,
      );
    });
  }

  // Crea la membresía (vínculo) + asegura la cuenta del invitado:
  // - si NO tiene cuenta → la crea con clave aleatoria y le manda el link de
  //   recuperación para que ponga la suya (invitación por correo).
  // - si YA tiene cuenta (p. ej. admin de otro negocio) → solo se vincula.
  Future<void> _inviteToBusinessId({
    required String businessId,
    required String name,
    required String email,
    required UserRole role,
  }) async {
    final emailLc = email.trim().toLowerCase();

    final dup = await _db
        .collection(AppConstants.colMemberships)
        .where('email', isEqualTo: emailLc)
        .where('businessId', isEqualTo: businessId)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) {
      throw Exception('Ese correo ya está vinculado a este negocio');
    }

    // 1) Asegurar la cuenta PRIMERO (así no queda una membresía huérfana si la
    // creación de cuenta falla por un motivo inesperado).
    String? newUid;
    bool existingAccount = false;
    try {
      newUid = await _createFirebaseUser(
          emailLc, 'Tmp${DateTime.now().millisecondsSinceEpoch}A1!');
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      existingAccount = true;
      // Ya tiene cuenta → solo se vincula (no hace falta crear nada).
    }

    // 2) Crear la membresía (vínculo).
    await _db.collection(AppConstants.colMemberships).add(Membership.toMap(
          email: emailLc,
          name: name,
          businessId: businessId,
          role: role,
          isActive: true,
        ));

    // 3a) Cuenta nueva: crear perfil + enviar link de contraseña.
    if (newUid != null) {
      await _db.collection(AppConstants.colUsers).doc(newUid).set({
        'email': emailLc,
        'name': name.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        // Array usado por las Firestore rules para aislar datos por negocio.
        'businessIds': [businessId],
      });
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(
        email: emailLc,
        actionCodeSettings: ActionCodeSettings(
          url: 'https://proyecto-app-negocio.web.app/recuperar',
          handleCodeInApp: true,
        ),
      );
    }

    // 3b) Cuenta existente vinculada a otro negocio: agregar este businessId
    // a su array para que las Firestore rules lo reconozcan.
    if (existingAccount) {
      final existing = await _db
          .collection(AppConstants.colUsers)
          .where('email', isEqualTo: emailLc)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'businessIds': FieldValue.arrayUnion([businessId]),
        });
      }
    }
  }

  // Admin: quita a un trabajador del negocio (borra su membresía aquí).
  Future<void> removeMembership(String membershipId) async {
    await _db.collection(AppConstants.colMemberships).doc(membershipId).delete();
  }

  // Admin: activa/desactiva a un trabajador (en este negocio).
  Future<void> setMembershipActive(String membershipId, bool active) async {
    await _db
        .collection(AppConstants.colMemberships)
        .doc(membershipId)
        .update({'isActive': active});
  }

  // Crea cuenta Firebase sin cerrar sesión del usuario actual (app secundaria).
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
    ref.read(selectedMembershipProvider.notifier).state = null;
    // Limpiar el carrito: en un dispositivo compartido, evita que el siguiente
    // usuario herede un carrito sin cobrar del anterior.
    ref.invalidate(cartProvider);
    await _auth.signOut();
  }

  // CEO: crear negocio (solo el negocio; el admin se invita aparte).
  Future<void> createBusiness(String name) async {
    await _db.collection(AppConstants.colBusinesses).add({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

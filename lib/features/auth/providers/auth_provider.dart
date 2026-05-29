import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/models/business_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final selectedBusinessProvider = StateProvider<Business?>((ref) => null);

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

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
    });
  }

  Future<void> register(String email, String password, String businessName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await ref
          .read(firebaseAuthProvider)
          .createUserWithEmailAndPassword(email: email.trim(), password: password);
      final uid = credential.user!.uid;
      final db = ref.read(firestoreProvider);
      await db.collection(AppConstants.colBusinesses).add({
        'name': businessName.trim(),
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> createBusiness(String name) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final db = ref.read(firestoreProvider);
    await db.collection(AppConstants.colBusinesses).add({
      'name': name.trim(),
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ref.invalidate(userBusinessesProvider);
  }

  Future<void> logout() async {
    ref.read(selectedBusinessProvider.notifier).state = null;
    await ref.read(firebaseAuthProvider).signOut();
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

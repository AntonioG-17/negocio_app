import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';

final _uuid = Uuid();

final clientsStreamProvider = StreamProvider<List<Client>>((ref) {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return const Stream.empty();
  final db = ref.watch(firestoreProvider);
  return db
      .collection(AppConstants.colClients)
      .where('businessId', isEqualTo: business.id)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(Client.fromFirestore).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });
});

final clientPaymentsProvider = StreamProvider.family<List<FiadoPayment>, String>((ref, clientId) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection(AppConstants.colPayments)
      .where('clientId', isEqualTo: clientId)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(FiadoPayment.fromFirestore).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

final totalDebtProvider = Provider<double>((ref) {
  final clients = ref.watch(clientsStreamProvider).valueOrNull ?? [];
  return clients.fold(0, (acc, c) => acc + c.totalDebt);
});

class FiadosNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);
  String get _businessId => ref.read(selectedBusinessProvider)!.id;

  Future<Client> addClient({required String name, String? phone}) async {
    final now = DateTime.now();
    final client = Client(
      id: _uuid.v4(),
      businessId: _businessId,
      name: name.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      totalDebt: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _db
        .collection(AppConstants.colClients)
        .doc(client.id)
        .set(client.toFirestore());
    return client;
  }

  Future<void> addPayment({
    required String clientId,
    String? clientName,
    required double amount,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final payment = FiadoPayment(
        id: _uuid.v4(),
        clientId: clientId,
        clientName: clientName,
        businessId: _businessId,
        amount: amount,
        note: note?.isEmpty == true ? null : note,
        createdAt: DateTime.now(),
      );
      final batch = _db.batch();
      batch.set(
        _db.collection(AppConstants.colPayments).doc(payment.id),
        payment.toFirestore(),
      );
      batch.update(
        _db.collection(AppConstants.colClients).doc(clientId),
        {
          'totalDebt': FieldValue.increment(-amount),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
    });
  }

  Future<void> deleteClient(String clientId) async {
    await _db.collection(AppConstants.colClients).doc(clientId).delete();
  }
}

final fiadosNotifierProvider =
    AsyncNotifierProvider<FiadosNotifier, void>(FiadosNotifier.new);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/inventory/models/product_model.dart';

final _uuid = Uuid();

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return const Stream.empty();
  final db = ref.watch(firestoreProvider);
  return db
      .collection(AppConstants.colProducts)
      .where('businessId', isEqualTo: business.id)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(Product.fromFirestore).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });
});

final lowStockProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsStreamProvider).valueOrNull ?? [];
  return products.where((p) => p.isLowStock).toList();
});

// autoDispose: cada escaneo usa ref.read una vez; sin autoDispose se acumularía
// una instancia por cada código distinto escaneado (fuga de memoria en sesiones largas).
final productByBarcodeProvider = Provider.autoDispose.family<Product?, String>((ref, barcode) {
  final products = ref.watch(productsStreamProvider).valueOrNull ?? [];
  return products.where((p) => p.barcode == barcode).firstOrNull;
});

class InventoryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);
  String get _businessId => ref.read(selectedBusinessProvider)!.id;

  Future<void> addProduct({
    required String name,
    String? barcode,
    required double price,
    double? cost,
    required int stock,
    required int minStock,
    String? category,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final now = DateTime.now();
      final product = Product(
        id: _uuid.v4(),
        businessId: _businessId,
        name: name,
        barcode: barcode?.isEmpty == true ? null : barcode,
        price: price,
        cost: cost,
        stock: stock,
        minStock: minStock,
        category: category?.isEmpty == true ? null : category,
        hasBarcode: barcode != null && barcode.isNotEmpty,
        createdAt: now,
        updatedAt: now,
      );
      await _db
          .collection(AppConstants.colProducts)
          .doc(product.id)
          .set(product.toFirestore());
    });
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db
          .collection(AppConstants.colProducts)
          .doc(product.id)
          .update(product.toFirestore());
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection(AppConstants.colProducts).doc(productId).delete();
  }
}

final inventoryNotifierProvider =
    AsyncNotifierProvider<InventoryNotifier, void>(InventoryNotifier.new);

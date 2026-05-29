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

final productByBarcodeProvider = Provider.family<Product?, String>((ref, barcode) {
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
          .update(product.copyWith().toFirestore());
    });
  }

  Future<void> deleteProduct(String productId) async {
    await _db.collection(AppConstants.colProducts).doc(productId).delete();
  }

  Future<void> updateStock(String productId, int newStock) async {
    await _db
        .collection(AppConstants.colProducts)
        .doc(productId)
        .update({'stock': newStock, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> decrementStock(String productId, int quantity) async {
    await _db
        .collection(AppConstants.colProducts)
        .doc(productId)
        .update({
      'stock': FieldValue.increment(-quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> seedDemoProducts() async {
    final existing = await _db
        .collection(AppConstants.colProducts)
        .where('businessId', isEqualTo: _businessId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final now = DateTime.now();
    final demo = [
      ('Chocolate Sublime', '7501234567890', 1200.0, 800.0, 50, 10, 'Dulces'),
      ('Chocolate Hershey\'s', '7509876543210', 1500.0, 1000.0, 30, 8, 'Dulces'),
      ('Cigarro Marlboro', '7500112233445', 3500.0, 2800.0, 20, 5, 'Cigarros'),
      ('Cigarro Lucky Strike', '7500556677889', 3200.0, 2600.0, 15, 5, 'Cigarros'),
      ('Coca-Cola 500ml', '7501055300242', 1200.0, 800.0, 60, 12, 'Bebidas'),
      ('Agua Mineral 500ml', '7501055301234', 600.0, 350.0, 80, 15, 'Bebidas'),
      ('Pan Molde', '7501033021234', 2500.0, 1800.0, 10, 3, 'Panaderia'),
      ('Leche 1L', '7501234512345', 1800.0, 1300.0, 25, 6, 'Lacteos'),
      ('Papas Fritas', '7509012345678', 900.0, 600.0, 40, 10, 'Snacks'),
      ('Detergente 500g', null, 2800.0, 2000.0, 8, 2, 'Limpieza'),
    ];

    final batch = _db.batch();
    for (final (name, barcode, price, cost, stock, minStock, category) in demo) {
      final id = _uuid.v4();
      final product = Product(
        id: id,
        businessId: _businessId,
        name: name,
        barcode: barcode,
        price: price,
        cost: cost,
        stock: stock,
        minStock: minStock,
        category: category,
        hasBarcode: barcode != null,
        createdAt: now,
        updatedAt: now,
      );
      batch.set(
        _db.collection(AppConstants.colProducts).doc(id),
        product.toFirestore(),
      );
    }
    await batch.commit();
  }
}

final inventoryNotifierProvider =
    AsyncNotifierProvider<InventoryNotifier, void>(InventoryNotifier.new);

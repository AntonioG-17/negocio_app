import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/inventory/models/product_model.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';
import 'package:negocio_app/features/pos/models/cart_item.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

final _uuid = Uuid();

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addProduct(Product product) {
    final idx = state.indexWhere((i) => i.product.id == product.id);
    if (idx != -1) {
      final updated = List<CartItem>.from(state);
      updated[idx].quantity++;
      state = updated;
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void removeProduct(String productId) {
    state = state.where((i) => i.product.id != productId).toList();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    state = state.map((i) {
      if (i.product.id == productId) {
        i.quantity = quantity;
      }
      return i;
    }).toList();
  }

  void clear() => state = [];

  double get total => state.fold(0, (sum, i) => sum + i.subtotal);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider.notifier).total;
});

class POSNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);
  String get _businessId => ref.read(selectedBusinessProvider)!.id;
  String get _userId => ref.read(firebaseAuthProvider).currentUser!.uid;

  Future<bool> scanBarcode(String barcode) async {
    final product = ref.read(productByBarcodeProvider(barcode));
    if (product == null) return false;
    if (product.stock <= 0) return false;
    ref.read(cartProvider.notifier).addProduct(product);
    return true;
  }

  Future<void> checkout({
    required PaymentType paymentType,
    Client? client,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cart = ref.read(cartProvider);
      if (cart.isEmpty) throw Exception('El carrito esta vacio');

      final items = cart
          .map((i) => SaleItem(
                productId: i.product.id,
                productName: i.product.name,
                quantity: i.quantity,
                price: i.product.price,
              ))
          .toList();

      final total = cart.fold<double>(0, (sum, i) => sum + i.subtotal);

      final sale = Sale(
        id: _uuid.v4(),
        businessId: _businessId,
        userId: _userId,
        items: items,
        total: total,
        paymentType: paymentType,
        clientId: client?.id,
        clientName: client?.name,
        createdAt: DateTime.now(),
      );

      final batch = _db.batch();

      batch.set(
        _db.collection(AppConstants.colSales).doc(sale.id),
        sale.toFirestore(),
      );

      for (final item in cart) {
        batch.update(
          _db.collection(AppConstants.colProducts).doc(item.product.id),
          {
            'stock': FieldValue.increment(-item.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      if (paymentType == PaymentType.fiado && client != null) {
        batch.update(
          _db.collection(AppConstants.colClients).doc(client.id),
          {
            'totalDebt': FieldValue.increment(total),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();
      ref.read(cartProvider.notifier).clear();
    });
  }
}

final posNotifierProvider = AsyncNotifierProvider<POSNotifier, void>(POSNotifier.new);

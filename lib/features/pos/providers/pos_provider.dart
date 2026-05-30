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
      final current = state[idx];
      if (current.quantity >= product.stock) return; // no superar stock
      final updated = List<CartItem>.from(state);
      updated[idx].quantity++;
      state = updated;
    } else {
      if (product.stock <= 0) return;
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
        final maxQty = i.product.stock;
        i.quantity = quantity > maxQty ? maxQty : quantity;
      }
      return i;
    }).toList();
  }

  void clear() => state = [];

  double get total => state.fold(0, (acc, i) => acc + i.subtotal);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (acc, i) => acc + i.subtotal);
});

class POSNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);
  String get _businessId => ref.read(selectedBusinessProvider)!.id;
  String get _userId => ref.read(firebaseAuthProvider).currentUser!.uid;
  String? get _userName => ref.read(userProfileProvider).valueOrNull?.name;

  // Retorna: 'added' | 'not_found' | 'no_stock'
  Future<String> scanBarcode(String barcode) async {
    final product = ref.read(productByBarcodeProvider(barcode));
    if (product == null) return 'not_found';
    if (product.stock <= 0) return 'no_stock';
    ref.read(cartProvider.notifier).addProduct(product);
    return 'added';
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

      final total = cart.fold<double>(0, (acc, i) => acc + i.subtotal);

      final sale = Sale(
        id: _uuid.v4(),
        businessId: _businessId,
        userId: _userId,
        userName: _userName,
        items: items,
        total: total,
        paymentType: paymentType,
        clientId: client?.id,
        clientName: client?.name,
        createdAt: DateTime.now(),
      );

      // Transacción: re-lee el stock real y aborta si el carrito supera lo
      // disponible (el stock pudo cambiar mientras estaba en el carrito).
      // Así nunca queda stock negativo ni se sobrevende.
      await _db.runTransaction((txn) async {
        // Fase de lectura (todas las lecturas antes de cualquier escritura).
        final snaps = <String, DocumentSnapshot>{};
        for (final item in cart) {
          final ref = _db.collection(AppConstants.colProducts).doc(item.product.id);
          snaps[item.product.id] = await txn.get(ref);
        }

        // Validación.
        for (final item in cart) {
          final snap = snaps[item.product.id]!;
          if (!snap.exists) {
            throw Exception('"${item.product.name}" ya no existe en el inventario');
          }
          final stock = ((snap.data() as Map<String, dynamic>)['stock'] as num?)?.toInt() ?? 0;
          if (stock < item.quantity) {
            throw Exception('Stock insuficiente de "${item.product.name}" (quedan $stock)');
          }
        }

        // Fase de escritura.
        txn.set(
          _db.collection(AppConstants.colSales).doc(sale.id),
          sale.toFirestore(),
        );
        for (final item in cart) {
          txn.update(
            _db.collection(AppConstants.colProducts).doc(item.product.id),
            {
              'stock': FieldValue.increment(-item.quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
        if (paymentType == PaymentType.fiado && client != null) {
          txn.update(
            _db.collection(AppConstants.colClients).doc(client.id),
            {
              'totalDebt': FieldValue.increment(total),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      });

      ref.read(cartProvider.notifier).clear();
    });
    if (!state.hasError) state = const AsyncData(null);
  }

  void resetState() => state = const AsyncData(null);
}

final posNotifierProvider = AsyncNotifierProvider<POSNotifier, void>(POSNotifier.new);

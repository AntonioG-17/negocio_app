import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  double get subtotal => quantity * price;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        productId: map['productId'] as String,
        productName: map['productName'] as String,
        quantity: (map['quantity'] as num).toInt(),
        price: (map['price'] as num).toDouble(),
      );
}

enum PaymentType { cash, card, fiado }

class Sale {
  final String id;
  final String businessId;
  final String userId;
  final List<SaleItem> items;
  final double total;
  final PaymentType paymentType;
  final String? clientId;
  final String? clientName;
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.items,
    required this.total,
    required this.paymentType,
    this.clientId,
    this.clientName,
    required this.createdAt,
  });

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id,
      businessId: d['businessId'] as String,
      userId: d['userId'] as String,
      items: (d['items'] as List<dynamic>)
          .map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      total: (d['total'] as num).toDouble(),
      paymentType: switch (d['paymentType']) {
        'fiado' => PaymentType.fiado,
        'card' => PaymentType.card,
        _ => PaymentType.cash,
      },
      clientId: d['clientId'] as String?,
      clientName: d['clientName'] as String?,
      createdAt: d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'businessId': businessId,
        'userId': userId,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'paymentType': switch (paymentType) {
          PaymentType.fiado => 'fiado',
          PaymentType.card => 'card',
          PaymentType.cash => 'cash',
        },
        'clientId': clientId,
        'clientName': clientName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

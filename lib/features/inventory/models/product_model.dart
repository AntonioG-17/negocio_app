import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String businessId;
  final String name;
  final String? barcode;
  final double price;
  final double? cost;
  final int stock;
  final int minStock;
  final String? category;
  final bool hasBarcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.barcode,
    required this.price,
    this.cost,
    required this.stock,
    required this.minStock,
    this.category,
    required this.hasBarcode,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => stock <= minStock;

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      businessId: d['businessId'] as String,
      name: d['name'] as String,
      barcode: d['barcode'] as String?,
      price: (d['price'] as num).toDouble(),
      cost: d['cost'] != null ? (d['cost'] as num).toDouble() : null,
      stock: (d['stock'] as num).toInt(),
      minStock: (d['minStock'] as num? ?? 5).toInt(),
      category: d['category'] as String?,
      hasBarcode: d['hasBarcode'] as bool? ?? false,
      createdAt: d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'businessId': businessId,
        'name': name,
        'barcode': barcode,
        'price': price,
        'cost': cost,
        'stock': stock,
        'minStock': minStock,
        'category': category,
        'hasBarcode': hasBarcode,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Product copyWith({
    String? name,
    String? barcode,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    String? category,
    bool? hasBarcode,
  }) {
    return Product(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      category: category ?? this.category,
      hasBarcode: hasBarcode ?? this.hasBarcode,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

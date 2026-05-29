import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final double totalDebt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    required this.totalDebt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Client(
      id: doc.id,
      businessId: d['businessId'] as String,
      name: d['name'] as String,
      phone: d['phone'] as String?,
      totalDebt: (d['totalDebt'] as num? ?? 0).toDouble(),
      createdAt: d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'businessId': businessId,
        'name': name,
        'phone': phone,
        'totalDebt': totalDebt,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Client copyWith({String? name, String? phone, double? totalDebt}) {
    return Client(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalDebt: totalDebt ?? this.totalDebt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class FiadoPayment {
  final String id;
  final String clientId;
  final String businessId;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const FiadoPayment({
    required this.id,
    required this.clientId,
    required this.businessId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory FiadoPayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FiadoPayment(
      id: doc.id,
      clientId: d['clientId'] as String,
      businessId: d['businessId'] as String,
      amount: (d['amount'] as num).toDouble(),
      note: d['note'] as String?,
      createdAt: d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'clientId': clientId,
        'businessId': businessId,
        'amount': amount,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

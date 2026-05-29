import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  const Business({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Business(
      id: doc.id,
      name: data['name'] as String,
      ownerId: data['ownerId'] as String,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ownerId': ownerId,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

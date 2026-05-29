import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { ceo, admin, worker }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? businessId;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.businessId,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      name: d['name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (d['role'] as String? ?? 'worker'),
        orElse: () => UserRole.worker,
      ),
      businessId: d['businessId'] as String?,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'name': name,
        'role': role.name,
        'businessId': businessId,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

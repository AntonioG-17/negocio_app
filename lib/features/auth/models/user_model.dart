import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { ceo, admin, worker }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? businessId;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.businessId,
    this.isActive = true,
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
      isActive: d['isActive'] as bool? ?? true,
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
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

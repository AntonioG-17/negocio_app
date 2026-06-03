import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';

// Vínculo persona ↔ negocio ↔ rol. La clave es el CORREO (en minúsculas), para
// poder vincular cuentas existentes y pre-crear invitaciones sin conocer el uid.
// Una persona puede tener varias membresías (admin en uno, trabajador en otro).
class Membership {
  final String id;
  final String email;
  final String name;
  final String businessId;
  final UserRole role; // admin | worker
  final bool isActive;
  final DateTime createdAt;

  const Membership({
    required this.id,
    required this.email,
    required this.name,
    required this.businessId,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory Membership.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Membership(
      id: doc.id,
      email: (d['email'] as String? ?? '').toLowerCase(),
      name: d['name'] as String? ?? '',
      businessId: d['businessId'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (d['role'] as String? ?? 'worker'),
        orElse: () => UserRole.worker,
      ),
      isActive: d['isActive'] as bool? ?? true,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  static Map<String, dynamic> toMap({
    required String email,
    required String name,
    required String businessId,
    required UserRole role,
    required bool isActive,
  }) =>
      {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'businessId': businessId,
        'role': role.name,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

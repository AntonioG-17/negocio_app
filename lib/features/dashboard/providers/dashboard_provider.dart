import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

class DashboardStats {
  final double todayRevenue;
  final int todaySalesCount;
  final double weekRevenue;
  final int lowStockCount;
  final double totalDebt;
  final List<Sale> recentSales;

  const DashboardStats({
    required this.todayRevenue,
    required this.todaySalesCount,
    required this.weekRevenue,
    required this.lowStockCount,
    required this.totalDebt,
    required this.recentSales,
  });
}

final todaySalesProvider = StreamProvider<List<Sale>>((ref) {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return const Stream.empty();

  final db = ref.watch(firestoreProvider);
  final role = ref.watch(currentUserRoleProvider);
  final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);

  return db
      .collection(AppConstants.colSales)
      .where('businessId', isEqualTo: business.id)
      .snapshots()
      .map((snap) {
    var sales = snap.docs.map(Sale.fromFirestore).toList();

    // Filtrar por fecha (hoy)
    sales = sales.where((s) => s.createdAt.isAfter(startOfDay)).toList();

    // Trabajador: solo sus propias ventas
    if (role == UserRole.worker && userId != null) {
      sales = sales.where((s) => s.userId == userId).toList();
    }

    sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sales;
  });
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final todaySales = ref.watch(todaySalesProvider).valueOrNull ?? [];
  final lowStockProducts = ref.watch(lowStockProductsProvider);

  final todayRevenue = todaySales
      .where((s) => s.paymentType != PaymentType.fiado)
      .fold<double>(0, (acc, s) => acc + s.total);

  return DashboardStats(
    todayRevenue: todayRevenue,
    todaySalesCount: todaySales.length,
    weekRevenue: 0,
    lowStockCount: lowStockProducts.length,
    totalDebt: 0,
    recentSales: todaySales.take(5).toList(),
  );
});

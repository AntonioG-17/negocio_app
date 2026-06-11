import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

class DashboardStats {
  final double todayRevenue;
  final int todaySalesCount;
  final double yesterdayRevenue;
  final int yesterdaySalesCount;
  final double weekRevenue;
  final int lowStockCount;
  final double totalDebt;
  final List<Sale> recentSales;
  final String? topProductName;
  final int topProductQty;

  const DashboardStats({
    required this.todayRevenue,
    required this.todaySalesCount,
    required this.yesterdayRevenue,
    required this.yesterdaySalesCount,
    required this.weekRevenue,
    required this.lowStockCount,
    required this.totalDebt,
    required this.recentSales,
    this.topProductName,
    this.topProductQty = 0,
  });

  // Diferencia porcentual de ingresos vs ayer. Null si no hay datos de ayer.
  double? get revenueChangePercent {
    if (yesterdayRevenue == 0) return null;
    return ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
  }
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
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) {
    var sales = snap.docs.map(Sale.fromFirestore).toList();
    if (role == UserRole.worker && userId != null) {
      sales = sales.where((s) => s.userId == userId).toList();
    }
    return sales;
  });
});

final yesterdaySalesProvider = FutureProvider<List<Sale>>((ref) async {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return [];

  final db = ref.read(firestoreProvider);
  final role = ref.watch(currentUserRoleProvider);
  final userId = ref.read(firebaseAuthProvider).currentUser?.uid;

  final now = DateTime.now();
  final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
  final endOfYesterday = DateTime(now.year, now.month, now.day);

  final snap = await db
      .collection(AppConstants.colSales)
      .where('businessId', isEqualTo: business.id)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYesterday))
      .where('createdAt', isLessThan: Timestamp.fromDate(endOfYesterday))
      .orderBy('createdAt', descending: true)
      .get();

  var sales = snap.docs.map(Sale.fromFirestore).toList();
  if (role == UserRole.worker && userId != null) {
    sales = sales.where((s) => s.userId == userId).toList();
  }
  return sales;
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final todaySales = ref.watch(todaySalesProvider).valueOrNull ?? [];
  final yesterdaySales = ref.watch(yesterdaySalesProvider).valueOrNull ?? [];
  final lowStockProducts = ref.watch(lowStockProductsProvider);

  final todayRevenue = todaySales
      .where((s) => s.paymentType != PaymentType.fiado)
      .fold<double>(0, (acc, s) => acc + s.total);

  final yesterdayRevenue = yesterdaySales
      .where((s) => s.paymentType != PaymentType.fiado)
      .fold<double>(0, (acc, s) => acc + s.total);

  // Producto más vendido del día por cantidad
  final productQty = <String, int>{};
  final productName = <String, String>{};
  for (final sale in todaySales) {
    for (final item in sale.items) {
      productQty[item.productId] =
          (productQty[item.productId] ?? 0) + item.quantity;
      productName[item.productId] = item.productName;
    }
  }
  String? topId;
  int topQty = 0;
  productQty.forEach((id, qty) {
    if (qty > topQty) {
      topQty = qty;
      topId = id;
    }
  });

  return DashboardStats(
    todayRevenue: todayRevenue,
    todaySalesCount: todaySales.length,
    yesterdayRevenue: yesterdayRevenue,
    yesterdaySalesCount: yesterdaySales.length,
    weekRevenue: 0,
    lowStockCount: lowStockProducts.length,
    totalDebt: 0,
    recentSales: todaySales.take(5).toList(),
    topProductName: topId != null ? productName[topId] : null,
    topProductQty: topQty,
  );
});

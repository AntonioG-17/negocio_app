import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

enum ReportPeriod { week, month, year }

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.week);

final reportSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return [];
  final period = ref.watch(reportPeriodProvider);
  final db = ref.watch(firestoreProvider);
  final now = DateTime.now();

  DateTime startDate;
  switch (period) {
    case ReportPeriod.week:
      startDate = now.subtract(const Duration(days: 7));
    case ReportPeriod.month:
      startDate = DateTime(now.year, now.month, 1);
    case ReportPeriod.year:
      startDate = DateTime(now.year, 1, 1);
  }

  final snap = await db
      .collection(AppConstants.colSales)
      .where('businessId', isEqualTo: business.id)
      .get();

  final all = snap.docs.map(Sale.fromFirestore).toList();
  final filtered = all.where((s) => s.createdAt.isAfter(startDate)).toList();
  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return filtered;
});

class ReportSummary {
  final double totalRevenue;
  final double cashRevenue;
  final double fiadoRevenue;
  final int totalSales;
  final Map<String, double> revenueByDay;

  const ReportSummary({
    required this.totalRevenue,
    required this.cashRevenue,
    required this.fiadoRevenue,
    required this.totalSales,
    required this.revenueByDay,
  });
}

final reportSummaryProvider = Provider<ReportSummary>((ref) {
  final sales = ref.watch(reportSalesProvider).valueOrNull ?? [];
  double cashRevenue = 0;
  double cardRevenue = 0;
  double fiadoRevenue = 0;
  final Map<String, double> byDay = {};

  for (final sale in sales) {
    final key = '${sale.createdAt.day}/${sale.createdAt.month}';
    byDay[key] = (byDay[key] ?? 0) + sale.total;
    switch (sale.paymentType) {
      case PaymentType.cash:
        cashRevenue += sale.total;
      case PaymentType.card:
        cardRevenue += sale.total;
      case PaymentType.fiado:
        fiadoRevenue += sale.total;
    }
  }

  return ReportSummary(
    totalRevenue: cashRevenue + cardRevenue + fiadoRevenue,
    cashRevenue: cashRevenue + cardRevenue,
    fiadoRevenue: fiadoRevenue,
    totalSales: sales.length,
    revenueByDay: byDay,
  );
});

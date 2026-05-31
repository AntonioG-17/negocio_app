import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

enum ReportPeriod { week, month, year }

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.week);

// Rango de fechas personalizado. Cuando no es null, manda sobre el periodo
// (permite elegir un día específico o un rango exacto para el Excel).
final customRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

DateTime _periodStart(ReportPeriod period) {
  final now = DateTime.now();
  return switch (period) {
    ReportPeriod.week => now.subtract(const Duration(days: 7)),
    ReportPeriod.month => DateTime(now.year, now.month, 1),
    ReportPeriod.year => DateTime(now.year, 1, 1),
  };
}

// Límites de fecha del reporte: inicio siempre; fin solo para rango personalizado
// (fin exclusivo = día elegido + 1, para incluir todo el último día).
final reportBoundsProvider = Provider<({DateTime start, DateTime? end})>((ref) {
  final custom = ref.watch(customRangeProvider);
  if (custom != null) {
    final start = DateTime(custom.start.year, custom.start.month, custom.start.day);
    final end = DateTime(custom.end.year, custom.end.month, custom.end.day)
        .add(const Duration(days: 1));
    return (start: start, end: end);
  }
  return (start: _periodStart(ref.watch(reportPeriodProvider)), end: null);
});

final reportSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return [];
  final db = ref.watch(firestoreProvider);
  final bounds = ref.watch(reportBoundsProvider);

  // Filtro de fecha en el servidor → solo trae el rango, no toda la colección.
  Query<Map<String, dynamic>> q = db
      .collection(AppConstants.colSales)
      .where('businessId', isEqualTo: business.id)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start));
  if (bounds.end != null) {
    q = q.where('createdAt', isLessThan: Timestamp.fromDate(bounds.end!));
  }
  final snap = await q.orderBy('createdAt', descending: true).get();

  return snap.docs.map(Sale.fromFirestore).toList();
});

// Pagos de fiados del periodo (para el Excel). Se incluye el nombre del cliente
// guardado en cada pago, por lo que el historial sobrevive aunque se borre el cliente.
final reportFiadoPaymentsProvider = FutureProvider<List<FiadoPayment>>((ref) async {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return [];
  final db = ref.watch(firestoreProvider);
  final bounds = ref.watch(reportBoundsProvider);

  Query<Map<String, dynamic>> q = db
      .collection(AppConstants.colPayments)
      .where('businessId', isEqualTo: business.id)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(bounds.start));
  if (bounds.end != null) {
    q = q.where('createdAt', isLessThan: Timestamp.fromDate(bounds.end!));
  }
  final snap = await q.orderBy('createdAt', descending: true).get();

  return snap.docs.map(FiadoPayment.fromFirestore).toList();
});

// Clientes con su deuda actual (snapshot, para el Excel).
final reportClientsProvider = FutureProvider<List<Client>>((ref) async {
  final business = ref.watch(selectedBusinessProvider);
  if (business == null) return [];
  final db = ref.watch(firestoreProvider);

  final snap = await db
      .collection(AppConstants.colClients)
      .where('businessId', isEqualTo: business.id)
      .get();

  final all = snap.docs.map(Client.fromFirestore).toList();
  all.sort((a, b) => a.name.compareTo(b.name));
  return all;
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';
import 'package:negocio_app/features/reports/providers/reports_provider.dart';
import 'package:negocio_app/features/reports/utils/excel_export.dart';

class DailyReportsScreen extends ConsumerStatefulWidget {
  const DailyReportsScreen({super.key});

  @override
  ConsumerState<DailyReportsScreen> createState() => _DailyReportsScreenState();
}

class _DailyReportsScreenState extends ConsumerState<DailyReportsScreen> {
  // Día que se está descargando (para mostrar el spinner en esa fila).
  DateTime? _downloading;

  Future<void> _downloadDay(DailyTotal d, Rect origin) async {
    if (_downloading != null) return;
    setState(() => _downloading = d.day);
    try {
      final db = ref.read(firestoreProvider);
      final business = ref.read(selectedBusinessProvider);
      if (business == null) return;

      final start = d.day;
      final end = d.day.add(const Duration(days: 1));

      // Ventas del día (los datos ya están guardados → se regenera el Excel).
      final salesSnap = await db
          .collection(AppConstants.colSales)
          .where('businessId', isEqualTo: business.id)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();
      final sales = salesSnap.docs.map(Sale.fromFirestore).toList();

      // Pagos de fiados del día.
      final paySnap = await db
          .collection(AppConstants.colPayments)
          .where('businessId', isEqualTo: business.id)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();
      final payments = paySnap.docs.map(FiadoPayment.fromFirestore).toList();

      // Deudas actuales de clientes (snapshot).
      final cliSnap = await db
          .collection(AppConstants.colClients)
          .where('businessId', isEqualTo: business.id)
          .get();
      final clients = cliSnap.docs.map(Client.fromFirestore).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      await exportReportToExcel(
        period: ReportPeriod.week,
        sales: sales,
        summary: buildReportSummary(sales),
        clients: clients,
        fiadoPayments: payments,
        customRange: DateTimeRange(start: d.day, end: d.day),
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(dailyTotalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes por día')),
      body: dailyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (days) => days.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy_outlined,
                        size: 64, color: AppTheme.onSurfaceMuted),
                    const SizedBox(height: 16),
                    Text('Sin ventas en los últimos 90 días',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Para días más antiguos usa el calendario en Reportes.',
                      style: TextStyle(color: AppTheme.onSurfaceMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.separated(
                // Margen inferior extra = safe area (evita que el último ítem
                // quede cortado por la barra de inicio del iPhone/Android).
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
                itemCount: days.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isLoading = _downloading == d.day;
                  return Card(
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const Icon(Icons.calendar_today_outlined,
                          color: AppTheme.primary),
                      title: Text(formatDate(d.day),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${d.count} venta${d.count == 1 ? '' : 's'} · ${formatCurrency(d.total)}',
                        style: const TextStyle(color: AppTheme.onSurfaceMuted),
                      ),
                      trailing: Builder(
                        builder: (btnCtx) => isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                              )
                            : IconButton(
                                icon: const Icon(Icons.file_download_outlined,
                                    color: AppTheme.primary),
                                tooltip: 'Descargar Excel',
                                onPressed: () {
                                  final box = btnCtx.findRenderObject() as RenderBox?;
                                  final origin = box != null
                                      ? box.localToGlobal(Offset.zero) & box.size
                                      : Rect.zero;
                                  _downloadDay(d, origin);
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

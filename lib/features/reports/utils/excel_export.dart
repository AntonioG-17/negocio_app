import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';
import 'package:negocio_app/features/reports/providers/reports_provider.dart';

Future<void> exportReportToExcel({
  required ReportPeriod period,
  required List<Sale> sales,
  required ReportSummary summary,
  Rect? sharePositionOrigin,
}) async {
  final excel = Excel.createExcel();

  final periodLabel = switch (period) {
    ReportPeriod.week => 'Ultimos 7 dias',
    ReportPeriod.month => 'Este mes',
    ReportPeriod.year => 'Este año',
  };

  // ── Hoja 1: Resumen ──────────────────────────────────────────
  final resSheet = excel['Resumen'];
  excel.delete('Sheet1');

  resSheet.appendRow([TextCellValue('Periodo'), TextCellValue(periodLabel)]);
  resSheet.appendRow([TextCellValue('Exportado'), TextCellValue(formatDate(DateTime.now()))]);
  resSheet.appendRow([TextCellValue(''), TextCellValue('')]);
  resSheet.appendRow([TextCellValue('Ingresos totales'), DoubleCellValue(summary.totalRevenue)]);
  resSheet.appendRow([TextCellValue('Total ventas'), IntCellValue(summary.totalSales)]);
  resSheet.appendRow([TextCellValue('Cobrado (ef. + tarj.)'), DoubleCellValue(summary.cashRevenue)]);
  resSheet.appendRow([TextCellValue('Fiados'), DoubleCellValue(summary.fiadoRevenue)]);

  // ── Hoja 2: Detalle de ventas ─────────────────────────────────
  final detSheet = excel['Ventas'];
  detSheet.appendRow([
    TextCellValue('Fecha'),
    TextCellValue('Hora'),
    TextCellValue('Trabajador'),
    TextCellValue('Productos'),
    TextCellValue('Total'),
    TextCellValue('Tipo de pago'),
    TextCellValue('Cliente'),
  ]);

  for (final sale in sales) {
    final items = sale.items.map((i) => '${i.productName} x${i.quantity}').join(', ');
    final payLabel = switch (sale.paymentType) {
      PaymentType.cash => 'Efectivo',
      PaymentType.card => 'Tarjeta',
      PaymentType.fiado => 'Fiado',
    };
    detSheet.appendRow([
      TextCellValue(formatDate(sale.createdAt)),
      TextCellValue(formatTime(sale.createdAt)),
      TextCellValue(sale.userName ?? '-'),
      TextCellValue(items),
      DoubleCellValue(sale.total),
      TextCellValue(payLabel),
      TextCellValue(sale.clientName ?? '-'),
    ]);
  }

  final bytes = excel.encode();
  if (bytes == null) throw Exception('No se pudo generar el archivo');

  final now = DateTime.now();
  final name =
      'reporte_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';
  const mime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final XFile xfile;
  if (kIsWeb) {
    // En web creamos el XFile directo desde memoria (sin sistema de archivos)
    xfile = XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: mime);
  } else {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    xfile = XFile(file.path, mimeType: mime);
  }

  await Share.shareXFiles(
    [xfile],
    subject: 'Reporte de ventas – $periodLabel',
    sharePositionOrigin: sharePositionOrigin,
  );
}

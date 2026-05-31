import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';
import 'package:negocio_app/features/reports/providers/reports_provider.dart';

Future<void> exportReportToExcel({
  required ReportPeriod period,
  required List<Sale> sales,
  required ReportSummary summary,
  List<Client> clients = const [],
  List<FiadoPayment> fiadoPayments = const [],
  DateTimeRange? customRange,
  Rect? sharePositionOrigin,
}) async {
  final excel = Excel.createExcel();

  final periodLabel = customRange != null
      ? (formatDate(customRange.start) == formatDate(customRange.end)
          ? formatDate(customRange.start)
          : 'Del ${formatDate(customRange.start)} al ${formatDate(customRange.end)}')
      : switch (period) {
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

  // ── Hoja 3: Fiados (deudas actuales) ──────────────────────────
  if (clients.isNotEmpty) {
    final cliSheet = excel['Fiados'];
    cliSheet.appendRow([
      TextCellValue('Cliente'),
      TextCellValue('Telefono'),
      TextCellValue('Deuda actual'),
    ]);
    final conDeuda = clients.where((c) => c.totalDebt > 0).toList();
    for (final c in conDeuda) {
      cliSheet.appendRow([
        TextCellValue(c.name),
        TextCellValue(c.phone ?? '-'),
        DoubleCellValue(c.totalDebt),
      ]);
    }
    cliSheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    cliSheet.appendRow([
      TextCellValue('TOTAL POR COBRAR'),
      TextCellValue(''),
      DoubleCellValue(conDeuda.fold<double>(0, (a, c) => a + c.totalDebt)),
    ]);
  }

  // ── Hoja 4: Pagos de fiados del periodo ───────────────────────
  if (fiadoPayments.isNotEmpty) {
    final pagSheet = excel['Pagos fiados'];
    pagSheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Hora'),
      TextCellValue('Cliente'),
      TextCellValue('Monto'),
      TextCellValue('Nota'),
    ]);
    for (final p in fiadoPayments) {
      pagSheet.appendRow([
        TextCellValue(formatDate(p.createdAt)),
        TextCellValue(formatTime(p.createdAt)),
        TextCellValue(p.clientName ?? '-'),
        DoubleCellValue(p.amount),
        TextCellValue(p.note ?? '-'),
      ]);
    }
    pagSheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    pagSheet.appendRow([
      TextCellValue('TOTAL PAGADO'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(fiadoPayments.fold<double>(0, (a, p) => a + p.amount)),
      TextCellValue(''),
    ]);
  }

  final bytes = excel.encode();
  if (bytes == null) throw Exception('No se pudo generar el archivo');

  String stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  final String name;
  if (customRange != null) {
    name = formatDate(customRange.start) == formatDate(customRange.end)
        ? 'reporte_${stamp(customRange.start)}.xlsx'
        : 'reporte_${stamp(customRange.start)}_a_${stamp(customRange.end)}.xlsx';
  } else {
    name = 'reporte_${stamp(DateTime.now())}.xlsx';
  }
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

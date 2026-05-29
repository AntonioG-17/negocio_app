import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/reports/providers/reports_provider.dart';
import 'package:negocio_app/features/reports/utils/excel_export.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;
  final _exportBtnKey = GlobalKey();

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final box = _exportBtnKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      final period = ref.read(reportPeriodProvider);
      final sales = ref.read(reportSalesProvider).valueOrNull ?? [];
      final summary = ref.read(reportSummaryProvider);
      await exportReportToExcel(
        period: period,
        sales: sales,
        summary: summary,
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
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final summary = ref.watch(reportSummaryProvider);
    final salesAsync = ref.watch(reportSalesProvider);
    final hasSales = salesAsync.valueOrNull?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          if (hasSales)
            _exporting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                  )
                : IconButton(
                    key: _exportBtnKey,
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip: 'Exportar Excel',
                    onPressed: _export,
                  ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<ReportPeriod>(
              segments: const [
                ButtonSegment(value: ReportPeriod.week, label: Text('7 dias')),
                ButtonSegment(value: ReportPeriod.month, label: Text('Mes')),
                ButtonSegment(value: ReportPeriod.year, label: Text('Año')),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(reportPeriodProvider.notifier).state = s.first,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppTheme.primary,
                selectedForegroundColor: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: salesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sales) => sales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bar_chart_outlined,
                              size: 64, color: AppTheme.onSurfaceMuted),
                          const SizedBox(height: 16),
                          Text('Sin ventas en este periodo',
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Ingresos totales',
                            value: formatCurrency(summary.totalRevenue),
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Total ventas',
                            value: '${summary.totalSales}',
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Cobrado',
                            value: formatCurrency(summary.cashRevenue),
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            label: 'Fiados',
                            value: formatCurrency(summary.fiadoRevenue),
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    if (summary.revenueByDay.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ingresos por dia',
                                  style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: _RevenueChart(data: summary.revenueByDay),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SalesBreakdown(summary: summary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final Map<String, double> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) return const SizedBox();

    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                color: AppTheme.primary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                entries[v.toInt()].key,
                style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceMuted),
              ),
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}

class _SalesBreakdown extends StatelessWidget {
  final ReportSummary summary;
  const _SalesBreakdown({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.totalRevenue == 0) return const SizedBox();
    final cashPct = (summary.cashRevenue / summary.totalRevenue * 100).toStringAsFixed(1);
    final fiadoPct = (summary.fiadoRevenue / summary.totalRevenue * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribucion de pagos',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _PctRow(label: 'Cobrado (ef. + tarj.)', pct: cashPct, color: AppTheme.success),
            const SizedBox(height: 8),
            _PctRow(label: 'Fiados', pct: fiadoPct, color: AppTheme.warning),
          ],
        ),
      ),
    );
  }
}

class _PctRow extends StatelessWidget {
  final String label;
  final String pct;
  final Color color;

  const _PctRow({required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: double.parse(pct) / 100,
            backgroundColor: AppTheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

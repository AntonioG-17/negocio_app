import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:negocio_app/features/fiados/providers/fiados_provider.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(selectedBusinessProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final totalDebt = ref.watch(totalDebtProvider);
    final lowStock = ref.watch(lowStockProductsProvider);
    final role = ref.watch(currentUserRoleProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    final isWorker = role == UserRole.worker;
    final isAdmin = role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            if (business != null)
              Text(business.name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
          ],
        ),
        actions: [
          // Botón equipo solo visible para admin
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Equipo',
              onPressed: () => context.push('/admin-panel'),
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todaySalesProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile != null) ...[
                Text(
                  'Hola, ${profile.name}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppTheme.primary),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Hoy, ${formatDate(DateTime.now())}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Stats de ventas
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: isWorker ? 'Mis ventas hoy' : 'Ventas hoy',
                      value: formatCurrency(stats.todayRevenue),
                      icon: Icons.trending_up,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Transacciones',
                      value: '${stats.todaySalesCount}',
                      icon: Icons.receipt_long_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),

              // Stats adicionales solo para admin
              if (!isWorker) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total fiados',
                        value: formatCurrency(totalDebt),
                        icon: Icons.people_outline,
                        color: AppTheme.warning,
                        onTap: () => context.go('/fiados'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Stock bajo',
                        value: '${lowStock.length} productos',
                        icon: Icons.warning_amber_outlined,
                        color: AppTheme.error,
                        onTap: () => context.go('/inventory'),
                      ),
                    ),
                  ],
                ),
              ],

              // Stock bajo (solo admin)
              if (!isWorker && lowStock.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Productos con stock bajo',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...lowStock.map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined,
                            color: AppTheme.error),
                        title: Text(p.name),
                        subtitle: Text('Stock: ${p.stock} (min. ${p.minStock})'),
                        trailing: TextButton(
                          onPressed: () => context.go('/inventory'),
                          child: const Text('Ver'),
                        ),
                      ),
                    )),
              ],

              // Últimas ventas
              const SizedBox(height: 24),
              Text(
                isWorker ? 'Mis últimas ventas' : 'Últimas ventas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (stats.recentSales.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        isWorker ? 'Sin ventas hoy' : 'Sin ventas hoy',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                ...stats.recentSales.map((sale) => _SaleTile(sale: sale)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final (title, icon, color) = switch (sale.paymentType) {
      PaymentType.fiado => (
          'Fiado – ${sale.clientName ?? ''}',
          Icons.person_outline,
          AppTheme.warning
        ),
      PaymentType.cash => (
          'Venta en efectivo',
          Icons.payments_outlined,
          AppTheme.success
        ),
      PaymentType.card => (
          'Venta con tarjeta',
          Icons.credit_card_outlined,
          const Color(0xFF4A90D9)
        ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          '${sale.items.length} producto(s) • ${formatTime(sale.createdAt)}',
        ),
        trailing: Text(
          formatCurrency(sale.total),
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

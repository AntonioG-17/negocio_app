import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/auth/widgets/change_password_dialog.dart';
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
    final isCeoPreview = ref.watch(isCeoPreviewProvider);

    return Scaffold(
      appBar: AppBar(
        leading: isCeoPreview
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver al panel CEO',
                onPressed: () {
                  ref.read(selectedBusinessProvider.notifier).state = null;
                  context.go('/ceo');
                },
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isCeoPreview ? 'Vista CEO' : (business?.name ?? 'Dashboard')),
            if (isCeoPreview && business != null)
              Text(business.name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
          ],
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.group_outlined),
              tooltip: 'Equipo',
              onPressed: () => context.push('/admin-panel'),
            ),
          if (!isCeoPreview)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'switch') {
                  ref.read(selectedBusinessProvider.notifier).state = null;
                  ref.read(selectedMembershipProvider.notifier).state = null;
                  context.go('/select-business');
                }
                if (v == 'password') showChangePasswordDialog(context, ref);
                if (v == 'logout') ref.read(authNotifierProvider.notifier).logout();
              },
              itemBuilder: (_) => [
                if ((ref.watch(userMembershipsProvider).valueOrNull?.length ?? 0) >= 2)
                  const PopupMenuItem(value: 'switch', child: Text('Cambiar negocio')),
                const PopupMenuItem(value: 'password', child: Text('Cambiar contraseña')),
                const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaySalesProvider);
          ref.invalidate(yesterdaySalesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saludo + fecha
              if (profile != null) ...[
                Text('Hola, ${profile.name}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppTheme.primary)),
                const SizedBox(height: 4),
              ],
              Text('Hoy, ${formatDate(DateTime.now())}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),

              // Tarjeta principal de ingresos con comparación vs ayer
              _RevenueCard(stats: stats, isWorker: isWorker),
              const SizedBox(height: 12),

              // Fila de stats secundarias
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Ventas',
                      value: '${stats.todaySalesCount}',
                      sub: stats.yesterdaySalesCount > 0
                          ? 'Ayer: ${stats.yesterdaySalesCount}'
                          : 'hoy',
                      icon: Icons.receipt_long_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (!isWorker) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Fiados',
                        value: formatCurrency(totalDebt),
                        sub: 'pendiente',
                        icon: Icons.people_outline,
                        color: AppTheme.warning,
                        onTap: () => context.go('/fiados'),
                      ),
                    ),
                  ],
                ],
              ),

              // Producto más vendido y stock bajo (solo admin)
              if (!isWorker) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Stock bajo',
                        value: '${lowStock.length}',
                        sub: lowStock.isEmpty ? 'todo OK' : 'productos',
                        icon: Icons.warning_amber_outlined,
                        color: lowStock.isEmpty ? AppTheme.success : AppTheme.error,
                        onTap: lowStock.isEmpty ? null : () => context.go('/inventory'),
                      ),
                    ),
                    if (stats.topProductName != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Más vendido',
                          value: stats.topProductName!,
                          sub: '${stats.topProductQty} uds hoy',
                          icon: Icons.star_outline_rounded,
                          color: const Color(0xFFFFD700),
                          isTextValue: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // Stock bajo detalle (solo admin)
              if (!isWorker && lowStock.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Stock bajo',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/inventory'),
                      child: const Text('Ver todo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lowStock.take(3).map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: AppTheme.error, size: 18),
                        ),
                        title: Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('Quedan ${p.stock} (mín. ${p.minStock})',
                            style: const TextStyle(color: AppTheme.error)),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppTheme.onSurfaceMuted),
                        onTap: () => context.go('/inventory'),
                      ),
                    )),
              ],

              // Últimas ventas
              const SizedBox(height: 24),
              Text(isWorker ? 'Mis últimas ventas' : 'Últimas ventas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (stats.recentSales.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 40, color: AppTheme.onSurfaceMuted),
                          const SizedBox(height: 12),
                          Text('Sin ventas hoy',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
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

// ── Tarjeta principal de ingresos ──────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final DashboardStats stats;
  final bool isWorker;
  const _RevenueCard({required this.stats, required this.isWorker});

  @override
  Widget build(BuildContext context) {
    final change = stats.revenueChangePercent;
    final isUp = change != null && change >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D5A), Color(0xFF1A1D27)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                isWorker ? 'Mis ingresos hoy' : 'Ingresos hoy',
                style: const TextStyle(
                    color: AppTheme.onSurfaceMuted, fontSize: 14),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUp
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isUp ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isUp ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatCurrency(stats.todayRevenue),
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          if (stats.yesterdayRevenue > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Ayer: ${formatCurrency(stats.yesterdayRevenue)}',
              style: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 13),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Sin datos de ayer',
              style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tarjeta de stat secundaria ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isTextValue;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.onTap,
    this.isTextValue = false,
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
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right,
                        color: AppTheme.onSurfaceMuted, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: isTextValue
                    ? TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)
                    : TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 12)),
              Text(sub,
                  style: const TextStyle(
                      color: AppTheme.onSurfaceMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile de venta ──────────────────────────────────────────────────────────

class _SaleTile extends StatelessWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (sale.paymentType) {
      PaymentType.fiado => (
          'Fiado – ${sale.clientName ?? ''}',
          Icons.person_outline,
          AppTheme.warning,
        ),
      PaymentType.cash => (
          'Efectivo',
          Icons.payments_outlined,
          AppTheme.success,
        ),
      PaymentType.card => (
          'Tarjeta',
          Icons.credit_card_outlined,
          const Color(0xFF4A90D9),
        ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${sale.items.length} producto${sale.items.length != 1 ? 's' : ''} · ${formatTime(sale.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          formatCurrency(sale.total),
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

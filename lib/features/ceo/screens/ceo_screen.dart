import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/models/business_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/auth/widgets/change_password_dialog.dart';

class CeoScreen extends ConsumerWidget {
  const CeoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(allBusinessesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Panel CEO'),
            Text('NegocioApp',
                style: TextStyle(fontSize: 12, color: AppTheme.primary)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'password') showChangePasswordDialog(context, ref);
              if (v == 'logout') {
                ref.read(authNotifierProvider.notifier).logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'password', child: Text('Cambiar contraseña')),
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: businesses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyState(
                onAdd: () => _showCreateDialog(context, ref),
              )
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Toca un negocio para ver su actividad (solo lectura)',
                        style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _BusinessCard(
                        business: list[i],
                        onTap: () {
                          // Entrar al preview: seleccionar el negocio y abrir el
                          // dashboard en modo solo lectura.
                          ref.read(selectedBusinessProvider.notifier).state = list[i];
                          context.go('/dashboard');
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo negocio'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    var creating = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Nuevo negocio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del negocio'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          StatefulBuilder(
            builder: (ctx2, setBtn) => ElevatedButton(
              // Guard contra doble-tap (crearía negocios duplicados).
              onPressed: creating
                  ? null
                  : () async {
                      if (ctrl.text.trim().isEmpty) return;
                      creating = true;
                      setBtn(() {});
                      await ref
                          .read(authNotifierProvider.notifier)
                          .createBusiness(ctrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('Crear'),
            ),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }
}

class _BusinessCard extends StatelessWidget {
  final Business business;
  final VoidCallback onTap;
  const _BusinessCard({required this.business, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      'Creado: ${_fmt(business.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.onSurfaceMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.onSurfaceMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined,
              size: 80, color: AppTheme.onSurfaceMuted),
          const SizedBox(height: 20),
          Text('Sin negocios aún',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Crea el primer negocio para comenzar',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Crear negocio'),
          ),
        ],
      ),
    );
  }
}

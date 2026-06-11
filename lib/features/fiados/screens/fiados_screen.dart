import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/fiados/providers/fiados_provider.dart';

class FiadosScreen extends ConsumerWidget {
  const FiadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsStreamProvider);
    final totalDebt = ref.watch(totalDebtProvider);
    final isCeoPreview = ref.watch(isCeoPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fiados')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total pendiente',
                    style: TextStyle(color: AppTheme.onSurfaceMuted)),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(totalDebt),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.warning),
                ),
              ],
            ),
          ),
          Expanded(
            child: clients.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 64, color: AppTheme.onSurfaceMuted),
                          const SizedBox(height: 16),
                          Text('Sin clientes con fiado',
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _ClientTile(client: list[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: isCeoPreview
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddClientDialog(context, ref),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Nuevo cliente'),
            ),
    );
  }

  void _showAddClientDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var creating = false;
    // Hoja inferior (sube con el teclado) en vez de AlertDialog.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nuevo cliente',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      // Guard contra doble-tap (crearía clientes duplicados).
                      onPressed: creating
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) return;
                              creating = true;
                              setSheet(() {});
                              await ref
                                  .read(fiadosNotifierProvider.notifier)
                                  .addClient(
                                    name: nameCtrl.text,
                                    phone: phoneCtrl.text.isEmpty
                                        ? null
                                        : phoneCtrl.text,
                                  );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: const Text('Crear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    });
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
          child: Text(
            client.name.isNotEmpty ? client.name.substring(0, 1).toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(client.name),
        subtitle: client.phone != null ? Text(client.phone!) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(client.totalDebt),
              style: TextStyle(
                color: client.totalDebt > 0 ? AppTheme.warning : AppTheme.success,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              client.totalDebt > 0 ? 'pendiente' : 'al dia',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted),
            ),
          ],
        ),
        onTap: () => context.go('/fiados/${client.id}'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

class BusinessSelectScreen extends ConsumerWidget {
  const BusinessSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(userBusinessesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu negocio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: businesses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyBusinesses(onCreated: () => ref.invalidate(userBusinessesProvider))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final biz = list[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.store, color: AppTheme.primary),
                      ),
                      title: Text(biz.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ref.read(selectedBusinessProvider.notifier).state = biz;
                        context.go('/dashboard');
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: businesses.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateBusinessDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo negocio'),
            )
          : null,
    );
  }

  void _showCreateBusinessDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Nuevo negocio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del negocio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(authNotifierProvider.notifier).createBusiness(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBusinesses extends ConsumerWidget {
  final VoidCallback onCreated;
  const _EmptyBusinesses({required this.onCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, size: 80, color: AppTheme.onSurfaceMuted),
          const SizedBox(height: 20),
          Text('No tienes negocios aun',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Crea tu primer negocio para comenzar',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Nombre del negocio'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(authNotifierProvider.notifier).createBusiness(ctrl.text);
              onCreated();
            },
            child: const Text('Crear negocio'),
          ),
        ],
      ),
    );
  }
}

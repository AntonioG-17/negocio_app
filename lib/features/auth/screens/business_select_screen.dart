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
            ? _EmptyBusinesses(onLogout: () => ref.read(authNotifierProvider.notifier).logout())
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
    );
  }
}

class _EmptyBusinesses extends StatelessWidget {
  final VoidCallback onLogout;
  const _EmptyBusinesses({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_outlined, size: 80, color: AppTheme.onSurfaceMuted),
          const SizedBox(height: 20),
          Text('Sin negocio asignado',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Tu cuenta aún no está asociada a ningún negocio.\nContacta al administrador.',
            style: TextStyle(color: AppTheme.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

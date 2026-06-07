import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

// Menú de selección de negocio (estilo CEO): aparece cuando una persona está
// vinculada a 2+ negocios. Toca un negocio → entra con su rol en ese negocio.
class BusinessSelectScreen extends ConsumerStatefulWidget {
  const BusinessSelectScreen({super.key});

  @override
  ConsumerState<BusinessSelectScreen> createState() =>
      _BusinessSelectScreenState();
}

class _BusinessSelectScreenState extends ConsumerState<BusinessSelectScreen> {
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(userMenuBusinessesProvider);
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
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyBusinesses(
                onLogout: () => ref.read(authNotifierProvider.notifier).logout())
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
                itemCount: list.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final it = list[i];
                  final isAdmin = it.membership.role == UserRole.admin;
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _selecting
                          ? null
                          : () async {
                              setState(() => _selecting = true);
                              await ref
                                  .read(authNotifierProvider.notifier)
                                  .selectMembership(it.membership);
                              if (context.mounted) context.go('/dashboard');
                              if (mounted) setState(() => _selecting = false);
                            },
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
                              child: const Icon(Icons.store,
                                  color: AppTheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.business.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(isAdmin ? 'Administrador' : 'Trabajador',
                                      style: const TextStyle(
                                          color: AppTheme.onSurfaceMuted,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                color: AppTheme.onSurfaceMuted, size: 16),
                          ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/models/membership_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(businessWorkersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Equipo de trabajo')),
      body: workers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? _EmptyWorkers(
                onAdd: () => _showCreateDialog(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _WorkerTile(worker: list[i]),
              ),
      ),
      // Solo el FAB cuando ya hay trabajadores. Con la lista vacía, el botón
      // central del estado vacío es el único (antes salían 2 botones).
      floatingActionButton: workers.maybeWhen(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Agregar trabajador'),
              ),
        orElse: () => null,
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surface,
      builder: (_) => const _InviteWorkerSheet(),
    );
  }
}

// ────────────────────────────────────────────────
// Tarjeta de trabajador
// ────────────────────────────────────────────────

class _WorkerTile extends ConsumerWidget {
  final Membership worker;
  const _WorkerTile({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: worker.isActive
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.onSurfaceMuted.withValues(alpha: 0.15),
              child: Text(
                worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: worker.isActive ? AppTheme.primary : AppTheme.onSurfaceMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    worker.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: worker.isActive ? null : AppTheme.onSurfaceMuted,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: worker.isActive
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    worker.isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: worker.isActive ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(worker.email,
                style: const TextStyle(color: AppTheme.onSurfaceMuted)),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
              tooltip: 'Remover del negocio',
              onPressed: () => _confirmRemove(context, ref),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  worker.isActive ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
                  size: 16,
                  color: AppTheme.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    worker.isActive
                        ? 'Habilitado para vender hoy'
                        : 'No puede ingresar a la app',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceMuted),
                  ),
                ),
                Switch(
                  value: worker.isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) => ref
                      .read(authNotifierProvider.notifier)
                      .setMembershipActive(worker.id, val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover trabajador'),
        content: Text('¿Remover a ${worker.name} del negocio?\n\nYa no podrá acceder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(authNotifierProvider.notifier)
                  .removeMembership(worker.id);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Hoja: invitar trabajador por correo (pone su propia contraseña)
// ────────────────────────────────────────────────

class _InviteWorkerSheet extends ConsumerStatefulWidget {
  const _InviteWorkerSheet();

  @override
  ConsumerState<_InviteWorkerSheet> createState() => _InviteWorkerSheetState();
}

class _InviteWorkerSheetState extends ConsumerState<_InviteWorkerSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresa el nombre');
      return;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Correo inválido');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authNotifierProvider.notifier).inviteWorker(
          name: name,
          email: email,
        );
    final s = ref.read(authNotifierProvider);
    if (!mounted) return;
    if (s.hasError) {
      setState(() {
        _saving = false;
        _error = _friendlyError(s.error);
      });
      return;
    }
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('Invitación enviada a $email. Le llegará un correo para '
          'crear su contraseña.'),
      backgroundColor: AppTheme.success,
    ));
  }

  String _friendlyError(Object? e) {
    final msg = e.toString();
    if (msg.contains('ya está vinculado')) {
      return 'Ese correo ya está en este negocio';
    }
    return 'No se pudo invitar. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invitar trabajador',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Le llegará un correo para crear su propia contraseña.',
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Invitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyWorkers({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline,
              size: 80, color: AppTheme.onSurfaceMuted),
          const SizedBox(height: 20),
          Text('Sin trabajadores aún',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Agrega trabajadores para que\npuedan vender en tu negocio',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Agregar trabajador'),
          ),
        ],
      ),
    );
  }
}

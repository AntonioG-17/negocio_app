import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/models/user_model.dart';
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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _WorkerTile(worker: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar trabajador'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateWorkerDialog(),
    );
  }
}

// ────────────────────────────────────────────────
// Tarjeta de trabajador
// ────────────────────────────────────────────────

class _WorkerTile extends ConsumerWidget {
  final UserModel worker;
  const _WorkerTile({required this.worker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: Text(
            worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(worker.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(worker.email,
            style: const TextStyle(color: AppTheme.onSurfaceMuted)),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
          tooltip: 'Remover del negocio',
          onPressed: () => _confirmRemove(context, ref),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
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
                  .removeWorker(worker.uid);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Dialogo: crear trabajador
// ────────────────────────────────────────────────

class _CreateWorkerDialog extends ConsumerStatefulWidget {
  const _CreateWorkerDialog();

  @override
  ConsumerState<_CreateWorkerDialog> createState() =>
      _CreateWorkerDialogState();
}

class _CreateWorkerDialogState extends ConsumerState<_CreateWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _done = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).createWorker(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
    final s = ref.read(authNotifierProvider);
    if (!mounted) return;
    if (s.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_friendlyError(s.error)),
        backgroundColor: AppTheme.error,
      ));
    } else {
      setState(() => _done = true);
    }
  }

  String _friendlyError(Object? e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) return 'Ese correo ya está registrado';
    return 'Error al crear la cuenta';
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    // Pantalla de confirmación con credenciales
    if (_done) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppTheme.success),
          SizedBox(width: 8),
          Text('Trabajador creado'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparte estas credenciales con el trabajador:',
              style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _CredBox(label: 'Nombre', value: _nameCtrl.text),
            const SizedBox(height: 6),
            _CredBox(label: 'Correo', value: _emailCtrl.text),
            const SizedBox(height: 6),
            _CredBox(label: 'Contraseña', value: _passCtrl.text),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Nuevo trabajador'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v?.trim().isEmpty == true ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) =>
                  v?.contains('@') == true ? null : 'Correo inválido',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña temporal',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v?.length ?? 0) >= 6 ? null : 'Mínimo 6 caracteres',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: loading ? null : _submit,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Text('Crear'),
        ),
      ],
    );
  }
}

class _CredBox extends StatelessWidget {
  final String label;
  final String value;
  const _CredBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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

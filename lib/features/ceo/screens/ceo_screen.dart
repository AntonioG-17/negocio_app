import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/models/business_model.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

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
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).logout(),
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
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _BusinessCard(business: list[i]),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateBusinessDialog(),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Business business;
  const _BusinessCard({required this.business});

  @override
  Widget build(BuildContext context) {
    return Card(
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
            const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ────────────────────────────────────────────────
// Dialogo: crear negocio + admin
// ────────────────────────────────────────────────

class _CreateBusinessDialog extends ConsumerStatefulWidget {
  const _CreateBusinessDialog();

  @override
  ConsumerState<_CreateBusinessDialog> createState() =>
      _CreateBusinessDialogState();
}

class _CreateBusinessDialogState
    extends ConsumerState<_CreateBusinessDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bizCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _done = false;

  @override
  void dispose() {
    _bizCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).createBusinessWithAdmin(
          businessName: _bizCtrl.text,
          adminName: _nameCtrl.text,
          adminEmail: _emailCtrl.text,
          adminPassword: _passCtrl.text,
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
    return 'Error al crear. Verifica los datos.';
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authNotifierProvider).isLoading;

    if (_done) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppTheme.success),
          SizedBox(width: 8),
          Text('¡Listo!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Negocio "${_bizCtrl.text}" creado.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Credenciales del admin:',
                style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            const SizedBox(height: 8),
            _CredBox(label: 'Correo', value: _emailCtrl.text),
            const SizedBox(height: 6),
            _CredBox(label: 'Contraseña', value: _passCtrl.text),
            const SizedBox(height: 12),
            const Text(
              'Guarda estas credenciales y entrégalas al admin.',
              style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Nuevo negocio + Admin'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _bizCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nombre del negocio'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Cuenta del admin',
                    style: TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 12)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del admin'),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Correo del admin'),
                validator: (v) =>
                    v?.contains('@') == true ? null : 'Correo inválido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña del admin',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.onSurfaceMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

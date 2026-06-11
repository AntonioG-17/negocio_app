import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

// Hoja inferior (no AlertDialog) para que suba con el teclado y los 3 campos
// queden siempre visibles y alcanzables al escribir.
Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppTheme.surface,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña actual');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'La nueva debe tener mínimo 6 caracteres');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden');
      return;
    }
    if (newPass == current) {
      setState(() => _error = 'La nueva debe ser distinta a la actual');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .changePassword(current, newPass);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendly(e);
      });
    }
  }

  String _friendly(Object e) {
    final m = e.toString();
    if (m.contains('wrong-password') ||
        m.contains('invalid-credential') ||
        m.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'La contraseña actual es incorrecta';
    }
    if (m.contains('weak-password')) return 'La nueva contraseña es muy débil';
    if (m.contains('requires-recent-login')) {
      return 'Por seguridad, cierra sesión, vuelve a entrar e intenta de nuevo';
    }
    return 'No se pudo cambiar. Intenta de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // El padding inferior = teclado → la hoja sube y todo queda visible.
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Cambiar contraseña',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _currentCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Contraseña actual',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Repetir nueva contraseña',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
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
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

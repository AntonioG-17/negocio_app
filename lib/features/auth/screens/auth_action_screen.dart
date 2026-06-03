import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';

// Página propia (marca NegocioApp) a la que llega el link del correo de
// recuperación / invitación. Verifica el código y deja crear la contraseña.
// Firebase manda: ?mode=resetPassword&oobCode=...  (acción "custom action URL").
class AuthActionScreen extends ConsumerStatefulWidget {
  final String? mode;
  final String? oobCode;
  const AuthActionScreen({super.key, this.mode, this.oobCode});

  @override
  ConsumerState<AuthActionScreen> createState() => _AuthActionScreenState();
}

enum _Phase { verifying, form, done, invalid }

class _AuthActionScreenState extends ConsumerState<AuthActionScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  String? _email;
  _Phase _phase = _Phase.verifying;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = widget.oobCode;
    if (code == null || code.isEmpty || widget.mode != 'resetPassword') {
      setState(() => _phase = _Phase.invalid);
      return;
    }
    try {
      final email = await ref
          .read(firebaseAuthProvider)
          .verifyPasswordResetCode(code);
      if (!mounted) return;
      setState(() {
        _email = email;
        _phase = _Phase.form;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.invalid);
    }
  }

  Future<void> _submit() async {
    final pass = _newCtrl.text;
    if (pass.length < 6) {
      setState(() => _error = 'Mínimo 6 caracteres');
      return;
    }
    if (pass != _confirmCtrl.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(firebaseAuthProvider)
          .confirmPasswordReset(code: widget.oobCode!, newPassword: pass);
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
    } catch (e) {
      if (!mounted) return;
      final m = e.toString();
      setState(() {
        _saving = false;
        _error = m.contains('expired') || m.contains('invalid')
            ? 'El enlace expiró. Pide uno nuevo.'
            : 'No se pudo guardar. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.storefront_outlined,
            color: AppTheme.primary, size: 46),
      );

  Widget _content() {
    switch (_phase) {
      case _Phase.verifying:
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        );

      case _Phase.invalid:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _logo(),
            const SizedBox(height: 24),
            Text('Enlace no válido',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Este enlace expiró o ya se usó. Vuelve a pedir el correo de '
              'recuperación desde la app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceMuted),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Ir a iniciar sesión'),
              ),
            ),
          ],
        );

      case _Phase.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 72),
            const SizedBox(height: 20),
            Text('¡Contraseña lista!',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Ya puedes iniciar sesión con tu nueva contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceMuted),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Iniciar sesión'),
              ),
            ),
          ],
        );

      case _Phase.form:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _logo()),
            const SizedBox(height: 24),
            Center(
              child: Text('Crea tu contraseña',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _email ?? '',
                style: const TextStyle(color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Repetir contraseña',
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Guardar contraseña'),
            ),
          ],
        );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/auth/providers/auth_provider.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/fiados/providers/fiados_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsStreamProvider).valueOrNull ?? [];
    final client = clients.where((c) => c.id == clientId).firstOrNull;
    final payments = ref.watch(clientPaymentsProvider(clientId));

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cliente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            onPressed: () => _delete(context, ref, client),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                      child: Text(
                        client.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          if (client.phone != null)
                            Text(client.phone!,
                                style: const TextStyle(color: AppTheme.onSurfaceMuted)),
                          const SizedBox(height: 8),
                          Text(
                            'Deuda: ${formatCurrency(client.totalDebt)}',
                            style: TextStyle(
                              color: client.totalDebt > 0
                                  ? AppTheme.warning
                                  : AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Historial de pagos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            payments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (list) => list.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text('Sin pagos registrados',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ),
                    )
                  : Column(
                      children: list
                          .map((p) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.payments_outlined,
                                      color: AppTheme.success),
                                  title: Text('+${formatCurrency(p.amount)}',
                                      style: const TextStyle(color: AppTheme.success)),
                                  subtitle: p.note != null ? Text(p.note!) : null,
                                  trailing: Text(formatDate(p.createdAt),
                                      style: const TextStyle(
                                          color: AppTheme.onSurfaceMuted)),
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: client.totalDebt > 0
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (client.phone != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton.icon(
                        onPressed: () => _sendReminder(context, ref, client),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Enviar recordatorio'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warning,
                          side: const BorderSide(color: AppTheme.warning),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                onPressed: () => _showAddPayment(context, ref, client),
                icon: const Icon(Icons.add),
                label: const Text('Registrar pago'),
              ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _sendReminder(BuildContext context, WidgetRef ref, Client client) async {
    final business = ref.read(selectedBusinessProvider);
    final businessName = business?.name ?? 'el negocio';
    final debt = formatCurrency(client.totalDebt);
    final phone = client.phone!.replaceAll(RegExp(r'[^\d+]'), '');

    final message = Uri.encodeComponent(
      'Hola ${client.name}, te recordamos que tienes una deuda pendiente de $debt en $businessName. '
      'Por favor acércate o comunícate con nosotros para coordinar el pago. ¡Muchas gracias!',
    );

    final whatsappUri = Uri.parse('https://wa.me/$phone?text=$message');
    final smsUri = Uri.parse('sms:$phone?body=$message');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp ni SMS'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showAddPayment(BuildContext context, WidgetRef ref, Client client) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar pago', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Deuda actual: ${formatCurrency(client.totalDebt)}',
                style: const TextStyle(color: AppTheme.warning)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Monto del pago *',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                await ref.read(fiadosNotifierProvider.notifier).addPayment(
                      clientId: client.id,
                      amount: amount,
                      note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirmar pago'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a ${client.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(fiadosNotifierProvider.notifier).deleteClient(client.id);
      if (context.mounted) context.pop();
    }
  }
}

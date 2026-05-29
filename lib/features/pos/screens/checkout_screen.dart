import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/fiados/models/client_model.dart';
import 'package:negocio_app/features/fiados/providers/fiados_provider.dart';
import 'package:negocio_app/features/pos/models/sale_model.dart';
import 'package:negocio_app/features/pos/providers/pos_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentType _paymentType = PaymentType.cash;
  Client? _selectedClient;

  Future<void> _confirmSale() async {
    if (_paymentType == PaymentType.fiado && _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente para el fiado'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    await ref.read(posNotifierProvider.notifier).checkout(
          paymentType: _paymentType,
          client: _selectedClient,
        );
    final state = ref.read(posNotifierProvider);
    if (!state.hasError && mounted) {
      _showSuccessDialog();
    } else if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${state.error}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    final paymentType = _paymentType;
    final clientName = _selectedClient?.name;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
            const SizedBox(height: 16),
            Text('Venta registrada',
                style: Theme.of(ctx).textTheme.titleLarge),
            if (paymentType == PaymentType.fiado)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Fiado a $clientName',
                    style: const TextStyle(color: AppTheme.warning)),
              )
            else if (paymentType == PaymentType.card)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Pagado con tarjeta',
                    style: TextStyle(color: Color(0xFF4A90D9))),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => ctx.go('/dashboard'),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _selectClient() {
    final clients = ref.read(clientsStreamProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (_) => _ClientPickerSheet(
        clients: clients,
        onSelect: (c) => setState(() => _selectedClient = c),
        onCreateNew: _createNewClient,
      ),
    );
  }

  Future<void> _createNewClient() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final client = await ref.read(fiadosNotifierProvider.notifier).addClient(
            name: nameCtrl.text,
            phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
          );
      setState(() => _selectedClient = client);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final posState = ref.watch(posNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar venta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ...cart.map((item) => ListTile(
                        title: Text(item.product.name),
                        subtitle: Text(
                            '${item.quantity} x ${formatCurrency(item.product.price)}'),
                        trailing: Text(
                          formatCurrency(item.subtotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      )),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      formatCurrency(total),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Tipo de pago', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaymentTypeCard(
                    label: 'Efectivo',
                    icon: Icons.payments_outlined,
                    selected: _paymentType == PaymentType.cash,
                    onTap: () => setState(() {
                      _paymentType = PaymentType.cash;
                      _selectedClient = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentTypeCard(
                    label: 'Tarjeta',
                    icon: Icons.credit_card_outlined,
                    selected: _paymentType == PaymentType.card,
                    color: const Color(0xFF4A90D9),
                    onTap: () => setState(() {
                      _paymentType = PaymentType.card;
                      _selectedClient = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentTypeCard(
                    label: 'Fiado',
                    icon: Icons.person_outline,
                    selected: _paymentType == PaymentType.fiado,
                    color: AppTheme.warning,
                    onTap: () => setState(() => _paymentType = PaymentType.fiado),
                  ),
                ),
              ],
            ),
            if (_paymentType == PaymentType.fiado) ...[
              const SizedBox(height: 20),
              Text('Cliente', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline, color: AppTheme.warning),
                  title: Text(_selectedClient?.name ?? 'Seleccionar cliente'),
                  subtitle: _selectedClient != null
                      ? Text('Deuda actual: ${formatCurrency(_selectedClient!.totalDebt)}')
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _selectClient,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: posState.isLoading ? null : _confirmSale,
              child: posState.isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(switch (_paymentType) {
                      PaymentType.fiado => 'Registrar fiado',
                      PaymentType.card => 'Cobrar con tarjeta',
                      PaymentType.cash => 'Confirmar venta',
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PaymentTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? color : AppTheme.surfaceVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : AppTheme.onSurfaceMuted, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppTheme.onSurfaceMuted,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final List<Client> clients;
  final ValueChanged<Client> onSelect;
  final VoidCallback onCreateNew;

  const _ClientPickerSheet({
    required this.clients,
    required this.onSelect,
    required this.onCreateNew,
  });

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.clients
        : widget.clients
            .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar cliente...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: AppTheme.primary),
                  title: const Text('Nuevo cliente',
                      style: TextStyle(color: AppTheme.primary)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onCreateNew();
                  },
                ),
                ...filtered.map((c) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(c.name),
                      subtitle: Text('Deuda: ${formatCurrency(c.totalDebt)}'),
                      onTap: () {
                        widget.onSelect(c);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

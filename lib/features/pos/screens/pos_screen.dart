import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/inventory/models/product_model.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';
import 'package:negocio_app/features/pos/models/cart_item.dart';
import 'package:negocio_app/features/pos/providers/pos_provider.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  bool _scannerActive = false;
  final _scannerCtrl = MobileScannerController();

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    setState(() => _scannerActive = false);
    final found = await ref.read(posNotifierProvider.notifier).scanBarcode(barcode);
    if (!found && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Codigo "$barcode" no encontrado'),
          backgroundColor: AppTheme.warning,
          action: SnackBarAction(
            label: 'Buscar',
            textColor: Colors.black,
            onPressed: _showManualSearch,
          ),
        ),
      );
    }
  }

  void _showManualSearch() {
    final products = ref.read(productsStreamProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => _ManualSearchSheet(products: products),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              icon: const Icon(Icons.clear_all, color: AppTheme.error),
              label: const Text('Limpiar', style: TextStyle(color: AppTheme.error)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scannerActive)
            _ScannerWidget(
              controller: _scannerCtrl,
              onDetect: _onBarcodeDetected,
              onClose: () => setState(() => _scannerActive = false),
            ),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 80, color: AppTheme.onSurfaceMuted),
                        const SizedBox(height: 16),
                        Text('Carrito vacio',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Escanea o busca un producto',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _CartTile(item: cart[i]),
                  ),
          ),
          _BottomBar(
            total: total,
            cartCount: cart.length,
            onScan: () => setState(() => _scannerActive = !_scannerActive),
            onSearch: _showManualSearch,
            onCheckout: () => context.go('/pos/checkout'),
          ),
        ],
      ),
    );
  }
}

class _ScannerWidget extends StatelessWidget {
  final MobileScannerController controller;
  final ValueChanged<String> onDetect;
  final VoidCallback onClose;

  const _ScannerWidget({
    required this.controller,
    required this.onDetect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null) onDetect(code);
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Apunta al codigo de barras',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: Theme.of(context).textTheme.bodyLarge),
                  Text(formatCurrency(item.product.price),
                      style: const TextStyle(color: AppTheme.onSurfaceMuted)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      cart.updateQuantity(item.product.id, item.quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.error,
                  iconSize: 22,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppTheme.primary),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (item.quantity >= item.product.stock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stock maximo: ${item.product.stock}'),
                          backgroundColor: AppTheme.warning,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      return;
                    }
                    cart.updateQuantity(item.product.id, item.quantity + 1);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.success,
                  iconSize: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  formatCurrency(item.subtotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final double total;
  final int cartCount;
  final VoidCallback onScan;
  final VoidCallback onSearch;
  final VoidCallback onCheckout;

  const _BottomBar({
    required this.total,
    required this.cartCount,
    required this.onScan,
    required this.onSearch,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.onSurface,
                    side: const BorderSide(color: AppTheme.surfaceVariant),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total ($cartCount producto${cartCount != 1 ? "s" : ""})',
                      style: const TextStyle(color: AppTheme.onSurfaceMuted)),
                  Text(
                    formatCurrency(total),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: cartCount > 0 ? onCheckout : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 52),
                ),
                child: const Text('Cobrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualSearchSheet extends ConsumerStatefulWidget {
  final List<Product> products;
  const _ManualSearchSheet({required this.products});

  @override
  ConsumerState<_ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends ConsumerState<_ManualSearchSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.products
        : widget.products
            .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
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
                      hintText: 'Buscar producto...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final p = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(p.name,
                          style: TextStyle(
                              color: p.stock <= 0 ? AppTheme.onSurfaceMuted : null)),
                      subtitle: Text(
                        p.stock <= 0 ? 'Sin stock' : 'Stock: ${p.stock}',
                        style: TextStyle(
                            color: p.stock <= 0 ? AppTheme.error : AppTheme.onSurfaceMuted),
                      ),
                      trailing: Text(
                        formatCurrency(p.price),
                        style: const TextStyle(
                            color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        if (p.stock <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sin stock disponible')),
                          );
                          return;
                        }
                        ref.read(cartProvider.notifier).addProduct(p);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

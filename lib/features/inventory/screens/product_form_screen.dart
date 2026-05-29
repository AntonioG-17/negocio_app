import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/features/inventory/models/product_model.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '${AppConstants.defaultMinStock}');
  final _categoryCtrl = TextEditingController();
  bool _hasBarcode = false;
  Product? _existingProduct;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
    }
  }

  void _loadProduct() {
    final products = ref.read(productsStreamProvider).valueOrNull ?? [];
    final p = products.where((p) => p.id == widget.productId).firstOrNull;
    if (p != null) {
      _existingProduct = p;
      _nameCtrl.text = p.name;
      _barcodeCtrl.text = p.barcode ?? '';
      _priceCtrl.text = p.price.toStringAsFixed(0);
      _costCtrl.text = p.cost?.toStringAsFixed(0) ?? '';
      _stockCtrl.text = p.stock.toString();
      _minStockCtrl.text = p.minStock.toString();
      _categoryCtrl.text = p.category ?? '';
      setState(() => _hasBarcode = p.hasBarcode);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (_) => const _BarcodeScannerSheet(),
    );
    if (result != null) {
      setState(() {
        _barcodeCtrl.text = result;
        _hasBarcode = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(inventoryNotifierProvider.notifier);
    if (_existingProduct != null) {
      final updated = _existingProduct!.copyWith(
        name: _nameCtrl.text.trim(),
        barcode: _hasBarcode ? _barcodeCtrl.text.trim() : null,
        price: double.parse(_priceCtrl.text),
        cost: _costCtrl.text.isNotEmpty ? double.tryParse(_costCtrl.text) : null,
        stock: int.parse(_stockCtrl.text),
        minStock: int.parse(_minStockCtrl.text),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        hasBarcode: _hasBarcode,
      );
      await notifier.updateProduct(updated);
    } else {
      await notifier.addProduct(
        name: _nameCtrl.text.trim(),
        barcode: _hasBarcode ? _barcodeCtrl.text.trim() : null,
        price: double.parse(_priceCtrl.text),
        cost: _costCtrl.text.isNotEmpty ? double.tryParse(_costCtrl.text) : null,
        stock: int.parse(_stockCtrl.text),
        minStock: int.parse(_minStockCtrl.text),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      );
    }
    final state = ref.read(inventoryNotifierProvider);
    if (!state.hasError && mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${_existingProduct?.name}"? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(inventoryNotifierProvider.notifier).deleteProduct(_existingProduct!.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryNotifierProvider);
    final isEdit = _existingProduct != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto *',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                validator: (v) => v?.trim().isEmpty == true ? 'Nombre requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Precio de venta *',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Ingresa un precio valido';
                    return null;
                  },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Costo (opcional)',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Stock actual *',
                        prefixIcon: Icon(Icons.inventory_outlined),
                      ),
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Stock invalido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Stock minimo',
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categoria (opcional)',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Text('Codigo de barras', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Este producto tiene codigo de barras'),
                value: _hasBarcode,
                onChanged: (v) => setState(() => _hasBarcode = v),
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              if (_hasBarcode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Codigo de barras',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        validator: (v) =>
                            _hasBarcode && (v?.trim().isEmpty ?? true) ? 'Ingresa el codigo' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(52, 52),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(isEdit ? 'Guardar cambios' : 'Agregar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final _ctrl = MobileScannerController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Escanea el codigo de barras',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _ctrl,
                onDetect: (capture) {
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null) Navigator.pop(context, code);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

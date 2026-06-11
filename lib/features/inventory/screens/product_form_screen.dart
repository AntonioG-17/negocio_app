import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/constants/app_constants.dart';
import 'package:negocio_app/core/scanner/web_scanner_bridge.dart';
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
  final _scanBtnKey = GlobalKey();
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
    hideScanTrigger();
    stopWebScanner();
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _armScanTrigger() {
    final box = _scanBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    showScanTrigger(
      x: offset.dx,
      y: offset.dy,
      width: box.size.width,
      height: box.size.height,
      onDetect: (code) {
        if (mounted) {
          setState(() {
            _barcodeCtrl.text = code;
            _hasBarcode = true;
          });
          Future.microtask(_armScanTrigger);
        }
      },
      onCancel: () {
        if (mounted) Future.microtask(_armScanTrigger);
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Código de barras único: evita que dos productos compartan el mismo código
    // (si no, al escanear siempre se encontraría solo el primero).
    if (_hasBarcode) {
      final code = _barcodeCtrl.text.trim();
      final products = ref.read(productsStreamProvider).valueOrNull ?? [];
      final dup = products.where((p) => p.barcode == code && p.id != _existingProduct?.id).firstOrNull;
      if (dup != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ese código ya lo usa "${dup.name}"'),
            backgroundColor: AppTheme.warning,
          ),
        );
        return;
      }
    }

    final notifier = ref.read(inventoryNotifierProvider.notifier);
    if (_existingProduct != null) {
      final updated = Product(
        id: _existingProduct!.id,
        businessId: _existingProduct!.businessId,
        name: _nameCtrl.text.trim(),
        barcode: _hasBarcode ? _barcodeCtrl.text.trim() : null,
        price: (double.tryParse(_priceCtrl.text) ?? 0).abs(),
        cost: _costCtrl.text.isNotEmpty ? (double.tryParse(_costCtrl.text) ?? 0).abs() : null,
        stock: (int.tryParse(_stockCtrl.text) ?? 0).abs(),
        minStock: int.tryParse(_minStockCtrl.text) ?? AppConstants.defaultMinStock,
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        hasBarcode: _hasBarcode,
        createdAt: _existingProduct!.createdAt,
        updatedAt: DateTime.now(),
      );
      await notifier.updateProduct(updated);
    } else {
      await notifier.addProduct(
        name: _nameCtrl.text.trim(),
        barcode: _hasBarcode ? _barcodeCtrl.text.trim() : null,
        price: (double.tryParse(_priceCtrl.text) ?? 0).abs(),
        cost: _costCtrl.text.isNotEmpty ? (double.tryParse(_costCtrl.text) ?? 0).abs() : null,
        stock: (int.tryParse(_stockCtrl.text) ?? 0).abs(),
        minStock: int.tryParse(_minStockCtrl.text) ?? AppConstants.defaultMinStock,
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
      );
    }
    final state = ref.read(inventoryNotifierProvider);
    if (!state.hasError && mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                onChanged: (v) {
                  setState(() => _hasBarcode = v);
                  if (v) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _armScanTrigger());
                  } else {
                    hideScanTrigger();
                  }
                },
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
                      key: _scanBtnKey,
                      onPressed: _armScanTrigger,
                      icon: const Icon(Icons.qr_code_scanner),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Guardar cambios' : 'Agregar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


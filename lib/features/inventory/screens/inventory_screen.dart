import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:negocio_app/core/theme/app_theme.dart';
import 'package:negocio_app/core/utils/formatters.dart';
import 'package:negocio_app/features/inventory/models/product_model.dart';
import 'package:negocio_app/features/inventory/providers/inventory_provider.dart';

final _searchProvider = StateProvider.autoDispose<String>((ref) => '');

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsStreamProvider);
    final search = ref.watch(_searchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(_searchProvider.notifier).state = v.toLowerCase(),
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final filtered = search.isEmpty
              ? list
              : list
                  .where((p) =>
                      p.name.toLowerCase().contains(search) ||
                      (p.barcode?.contains(search) ?? false) ||
                      (p.category?.toLowerCase().contains(search) ?? false))
                  .toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: AppTheme.onSurfaceMuted),
                  const SizedBox(height: 16),
                  Text(
                    search.isEmpty ? 'Sin productos' : 'Sin resultados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _ProductTile(product: filtered[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/inventory/add'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: product.isLowStock
                ? AppTheme.error.withValues(alpha: 0.15)
                : AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            product.hasBarcode
                ? Icons.qr_code_outlined
                : Icons.inventory_2_outlined,
            color: product.isLowStock ? AppTheme.error : AppTheme.primary,
            size: 22,
          ),
        ),
        title: Text(product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock: ${product.stock}${product.isLowStock ? " ⚠ bajo" : ""}',
              style: TextStyle(
                color: product.isLowStock ? AppTheme.error : AppTheme.onSurfaceMuted,
              ),
            ),
            if (product.barcode != null)
              Text('CB: ${product.barcode}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(product.price),
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            if (product.category != null)
              Text(product.category!,
                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceMuted)),
          ],
        ),
        onTap: () => context.go('/inventory/edit/${product.id}'),
      ),
    );
  }
}

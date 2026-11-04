import 'package:database/database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

/// Full CRUD Product and Category Catalog management table for Windows Desktop Admin.
class ProductCatalogScreen extends StatefulWidget {
  final AppDatabase database;

  const ProductCatalogScreen({
    super.key,
    required this.database,
  });

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await widget.database.getAllProducts();
    final categories = await widget.database.getAllCategories();
    if (mounted) {
      setState(() {
        _allProducts = products;
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.trim().isEmpty) {
      return _allProducts;
    }
    final q = _searchQuery.toLowerCase();
    return _allProducts.where((p) {
      final nameMatch = p.name.toLowerCase().contains(q);
      final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(q);
      final skuMatch = p.sku != null && p.sku!.toLowerCase().contains(q);
      return nameMatch || barcodeMatch || skuMatch;
    }).toList();
  }

  Future<void> _toggleProduct(Product p) async {
    await widget.database.toggleProductActive(p.id, !p.isActive);
    await _loadData();
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final catId = 'cat-${DateTime.now().millisecondsSinceEpoch}';
                await widget.database.upsertCategory(
                  CategoriesCompanion.insert(
                    id: catId,
                    name: name,
                    description: Value(descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null),
                  ),
                );
                if (mounted) Navigator.of(ctx).pop();
                await _loadData();
              }
            },
            child: const Text('Save Category'),
          ),
        ],
      ),
    );
  }

  void _showProductDialog([Product? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final sellPriceCtrl = TextEditingController(text: existing != null ? existing.sellingPrice.toStringAsFixed(2) : '');
    final costPriceCtrl = TextEditingController(text: existing?.purchasePrice != null ? existing!.purchasePrice!.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stockQuantity.toString() : '0');
    String? selectedCategoryId = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Product Entry' : 'Edit Product', style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('input_product_name'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_barcode'),
                          controller: barcodeCtrl,
                          decoration: const InputDecoration(labelText: 'Barcode (EAN/UPC)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_sku'),
                          controller: skuCtrl,
                          decoration: const InputDecoration(labelText: 'Store SKU', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_selling_price'),
                          controller: sellPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_purchase_price'),
                          controller: costPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Purchase / Cost Price (₹)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('input_product_stock'),
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Initial Stock Quantity', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final sell = double.tryParse(sellPriceCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costPriceCtrl.text.trim());
                final stock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                final barcode = barcodeCtrl.text.trim();
                final sku = skuCtrl.text.trim();

                if (name.isNotEmpty && sell > 0) {
                  final prodId = existing?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
                  await widget.database.upsertProduct(
                    ProductsCompanion.insert(
                      id: prodId,
                      name: name,
                      barcode: Value(barcode.isNotEmpty ? barcode : null),
                      sku: Value(sku.isNotEmpty ? sku : null),
                      categoryId: Value(selectedCategoryId),
                      sellingPrice: sell,
                      purchasePrice: Value(cost),
                      stockQuantity: Value(stock),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  if (mounted) Navigator.of(ctx).pop();
                  await _loadData();
                }
              },
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product & Category Catalog',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Manage items, pricing, inventory stock, and classification',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showAddCategoryDialog,
                            icon: const Icon(Icons.category_outlined, size: 18),
                            label: const Text('Add Category'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showProductDialog(),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search input
                  Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search by name, barcode, or SKU...',
                        prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Products Data Table Container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          itemCount: products.length + 1,
                          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildTableHeader();
                            }
                            final p = products[index - 1];
                            return _buildProductRow(p);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Barcode / SKU', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Stock Quantity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.barcode ?? '-',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontFamily: 'monospace'),
                ),
                if (p.sku != null)
                  Text(
                    p.sku!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${p.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              p.purchasePrice != null ? '₹${p.purchasePrice!.toStringAsFixed(2)}' : '-',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${p.stockQuantity} ${p.unit}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: p.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  p.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Edit Product',
                  onPressed: () => _showProductDialog(p),
                ),
                IconButton(
                  key: Key('toggle_active_${p.id}'),
                  icon: Icon(
                    p.isActive ? Icons.toggle_on : Icons.toggle_off,
                    size: 26,
                    color: p.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                  tooltip: p.isActive ? 'Deactivate' : 'Activate',
                  onPressed: () => _toggleProduct(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

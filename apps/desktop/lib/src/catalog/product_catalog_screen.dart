import 'dart:io';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../labels/shelf_label_generator.dart';
import 'barcode_generator.dart';
import 'csv_catalog_service.dart';

/// Full CRUD Product, Variant, and Category Catalog management for Windows Desktop Admin.
/// Includes Bulk CSV Import/Export, Batch Thermal Shelf Label Printing, and Low-Stock Reordering.
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
  String? _selectedCategoryFilter; // null means 'All'
  bool _filterLowStockOnly = false;
  final Set<String> _selectedProductIds = {};
  bool _isLoading = true;
  String? _loadError;

  static const List<String> _commonUnits = [
    'pcs',
    'kg',
    'g',
    'l',
    'ml',
    'pack',
    'box',
    'bundle',
  ];

  static const List<double> _gstSlabs = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final products = await widget.database.getAllProducts();
      final categories = await widget.database.getAllCategories();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _categories = categories;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading catalog data: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  List<Product> get _filteredProducts {
    var list = _allProducts;

    // Filter by Low Stock
    if (_filterLowStockOnly) {
      list = list.where((p) => p.stockQuantity <= p.minStockAlert).toList();
    }

    // Filter by Category
    if (_selectedCategoryFilter != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryFilter).toList();
    }

    // Filter by Search query
    if (_searchQuery.trim().isEmpty) {
      return list;
    }

    final q = _searchQuery.toLowerCase();
    return list.where((p) {
      final nameMatch = p.name.toLowerCase().contains(q);
      final variantMatch = p.variantName != null && p.variantName!.toLowerCase().contains(q);
      final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(q);
      final secBarcodeMatch = p.secondaryBarcode != null && p.secondaryBarcode!.toLowerCase().contains(q);
      final skuMatch = p.sku != null && p.sku!.toLowerCase().contains(q);
      return nameMatch || variantMatch || barcodeMatch || secBarcodeMatch || skuMatch;
    }).toList();
  }

  int get _lowStockCount => _allProducts.where((p) => p.stockQuantity <= p.minStockAlert).length;

  Future<void> _toggleProduct(Product p) async {
    await widget.database.toggleProductActive(p.id, !p.isActive);
    await _loadData();
  }

  // --- CSV Export ---
  Future<void> _exportCatalog() async {
    final csv = CsvCatalogService.exportToCsv(_allProducts, _categories);
    final file = await CsvCatalogService.saveCsvToFile('grocery_catalog_export', csv);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catalog exported successfully to: ${file.path}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- CSV Import Modal ---
  void _showCsvImportDialog() {
    final contentCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    List<CsvProductRow> parsedRows = [];
    bool isParsed = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final validCount = parsedRows.where((r) => r.isValid).length;
          final invalidCount = parsedRows.where((r) => !r.isValid).length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.file_upload_outlined, color: Color(0xFF10B981), size: 24),
                    SizedBox(width: 8),
                    Text('Bulk Catalog CSV Import', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final template = CsvCatalogService.generateSampleCsvTemplate();
                    final file = await CsvCatalogService.saveCsvToFile('grocery_catalog_sample_template', template);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sample CSV template saved to: ${file.path}'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Sample CSV'),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Load CSV file from disk or paste CSV content below:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pathCtrl,
                            decoration: const InputDecoration(
                              labelText: 'CSV File Path (e.g. C:\\Users\\...\\catalog.csv)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final p = pathCtrl.text.trim();
                            if (p.isNotEmpty && File(p).existsSync()) {
                              final text = await File(p).readAsString();
                              setDialogState(() {
                                contentCtrl.text = text;
                                parsedRows = CsvCatalogService.parseCsv(text);
                                isParsed = true;
                              });
                            }
                          },
                          child: const Text('Load File'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Or Paste CSV Raw Content',
                        hintText: 'Name,Variant,Barcode,SecondaryBarcode,SKU,Category,SellingPrice,CostPrice...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (text) {
                        setDialogState(() {
                          if (text.trim().isNotEmpty) {
                            parsedRows = CsvCatalogService.parseCsv(text);
                            isParsed = true;
                          } else {
                            parsedRows = [];
                            isParsed = false;
                          }
                        });
                      },
                    ),
                    if (isParsed) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: invalidCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: invalidCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              invalidCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                              color: invalidCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Parsed ${parsedRows.length} rows: $validCount valid, $invalidCount invalid',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: invalidCount > 0 ? const Color(0xFF92400E) : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (invalidCount > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: parsedRows.where((r) => !r.isValid).map((r) {
                              return Text(
                                '• Line ${r.lineNumber} (${r.name.isEmpty ? "No Name" : r.name}): ${r.errors.join(", ")}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
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
                onPressed: validCount == 0
                    ? null
                    : () async {
                        // 1. Resolve or create categories
                        final existingCats = {for (final c in _categories) c.name.toLowerCase(): c.id};
                        for (final row in parsedRows.where((r) => r.isValid && r.categoryName != null)) {
                          final catKey = row.categoryName!.toLowerCase();
                          if (!existingCats.containsKey(catKey)) {
                            final catId = 'cat-${DateTime.now().millisecondsSinceEpoch}-${existingCats.length}';
                            await widget.database.upsertCategory(
                              CategoriesCompanion.insert(
                                id: catId,
                                name: row.categoryName!,
                                defaultTaxRate: Value(row.taxRate),
                                defaultHsnCode: Value(row.hsnCode),
                              ),
                            );
                            existingCats[catKey] = catId;
                          }
                        }

                        // 2. Insert valid products
                        for (final row in parsedRows.where((r) => r.isValid)) {
                          final catId = row.categoryName != null ? existingCats[row.categoryName!.toLowerCase()] : null;
                          final prodId = 'prod-${DateTime.now().millisecondsSinceEpoch}-${row.lineNumber}';
                          await widget.database.upsertProduct(
                            ProductsCompanion.insert(
                              id: prodId,
                              name: row.name,
                              variantName: Value(row.variant),
                              barcode: Value(row.barcode),
                              secondaryBarcode: Value(row.secondaryBarcode),
                              sku: Value(row.sku),
                              categoryId: Value(catId),
                              sellingPrice: row.sellingPrice,
                              purchasePrice: Value(row.costPrice),
                              stockQuantity: Value(row.stockQuantity),
                              unit: Value(row.unit),
                              taxRate: Value(row.taxRate),
                              hsnCode: Value(row.hsnCode),
                              minStockAlert: Value(row.minStockAlert),
                              updatedAt: DateTime.now(),
                            ),
                          );
                        }

                        if (mounted) Navigator.of(ctx).pop();
                        await _loadData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully imported $validCount products into catalog!'),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Commit Import ($validCount Items)'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Batch Thermal Shelf Labels Printing ---
  Future<void> _printBatchLabels() async {
    final selected = _allProducts.where((p) => _selectedProductIds.contains(p.id)).toList();
    if (selected.isEmpty) return;

    final items = selected.map((p) {
      final displayName = p.variantName != null ? '${p.name} (${p.variantName})' : p.name;
      return ProductLabelData(
        name: displayName,
        barcode: p.barcode ?? p.sku ?? p.id,
        sku: p.sku,
        sellingPrice: p.sellingPrice,
        unit: p.unit,
      );
    }).toList();

    await Printing.layoutPdf(
      onLayout: (format) => ShelfLabelGenerator.generateBatch(
        store: const LabelStoreInfo(storeName: 'WebotApp Store'),
        products: items,
      ),
      name: 'Batch_Labels_${selected.length}_items',
    );
  }

  // --- Category Dialog ---
  void _showAddCategoryDialog([Category? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final hsnCtrl = TextEditingController(text: existing?.defaultHsnCode ?? '');
    double selectedGst = existing?.defaultTaxRate ?? 5.0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'New Store Category' : 'Edit Category',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Staples & Grains, Dairy & Bakery',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          isExpanded: true,
                          value: selectedGst,
                          decoration: const InputDecoration(
                            labelText: 'Default GST Slab',
                            border: OutlineInputBorder(),
                          ),
                          items: _gstSlabs.map((rate) {
                            return DropdownMenuItem(
                              value: rate,
                              child: Text(rate == 0 ? '0% (Exempt)' : '$rate% GST'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedGst = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hsnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Default HSN Code',
                            hintText: 'e.g. 1006',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
                if (name.isNotEmpty) {
                  final catId = existing?.id ?? 'cat-${DateTime.now().millisecondsSinceEpoch}';
                  await widget.database.upsertCategory(
                    CategoriesCompanion.insert(
                      id: catId,
                      name: name,
                      description: Value(descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null),
                      defaultTaxRate: Value(selectedGst),
                      defaultHsnCode: Value(hsnCtrl.text.trim().isNotEmpty ? hsnCtrl.text.trim() : null),
                    ),
                  );
                  if (mounted) Navigator.of(ctx).pop();
                  await _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Product & Variant Dialog ---
  void _showProductDialog([Product? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final variantCtrl = TextEditingController(text: existing?.variantName ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final secBarcodeCtrl = TextEditingController(text: existing?.secondaryBarcode ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final sellPriceCtrl = TextEditingController(text: existing != null ? existing.sellingPrice.toStringAsFixed(2) : '');
    final costPriceCtrl = TextEditingController(text: existing?.purchasePrice != null ? existing!.purchasePrice!.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stockQuantity.toString() : '10');
    final minStockCtrl = TextEditingController(text: existing != null ? existing.minStockAlert.toString() : '5');
    final hsnCtrl = TextEditingController(text: existing?.hsnCode ?? '');

    String selectedUnit = existing?.unit ?? 'pcs';
    double selectedTaxRate = existing?.taxRate ?? 5.0;
    String? selectedCategoryId = existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);
    String? selectedParentId = existing?.parentProductId;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                existing == null ? Icons.add_box_rounded : Icons.edit_note_rounded,
                color: const Color(0xFF10B981),
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                existing == null ? 'New Product Entry' : 'Edit Product: ${existing.name}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name & Variant Name
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: const Key('input_product_name'),
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Product / Brand Name *',
                            hintText: 'e.g. Tata Salt, Fortune Oil, Basmati Rice',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('input_variant_name'),
                          controller: variantCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Variant / Pack Size',
                            hintText: 'e.g. 500g, 1kg, 5L, Pack of 4',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Parent Product Linker & Unit
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: selectedParentId,
                          decoration: const InputDecoration(
                            labelText: 'Group under Parent Product (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Standalone Product (No Parent)'),
                            ),
                            ..._allProducts
                                .where((p) => p.id != existing?.id && p.parentProductId == null)
                                .map((p) => DropdownMenuItem<String?>(
                                      value: p.id,
                                      child: Text(
                                        'Variant of: ${p.name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                          ],
                          onChanged: (val) => setDialogState(() => selectedParentId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit of Measure *',
                            border: OutlineInputBorder(),
                          ),
                          items: _commonUnits.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u.toUpperCase()));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Primary Barcode & Auto Generator Button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_barcode'),
                          controller: barcodeCtrl,
                          decoration: InputDecoration(
                            labelText: 'Primary Barcode (EAN/UPC)',
                            hintText: 'Scan or click generate',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981)),
                              tooltip: 'Auto Generate GS1 EAN-13 Barcode',
                              onPressed: () {
                                final generated = BarcodeGenerator.generateEan13(prefix: '20');
                                setDialogState(() => barcodeCtrl.text = generated);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: secBarcodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Secondary / Case Barcode',
                            hintText: 'e.g. Outer Box or Pack barcode',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Store SKU & Category
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_sku'),
                          controller: skuCtrl,
                          decoration: InputDecoration(
                            labelText: 'Store SKU',
                            hintText: 'e.g. SKU-10492',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                              tooltip: 'Auto Generate SKU',
                              onPressed: () {
                                final sku = BarcodeGenerator.generateStoreSku();
                                setDialogState(() => skuCtrl.text = sku);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCategoryId = val;
                              if (val != null) {
                                final matchedCat = _categories.firstWhere((c) => c.id == val);
                                selectedTaxRate = matchedCat.defaultTaxRate;
                                if (matchedCat.defaultHsnCode != null && hsnCtrl.text.isEmpty) {
                                  hsnCtrl.text = matchedCat.defaultHsnCode!;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pricing & Tax Slabs
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_selling_price'),
                          controller: sellPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (₹) *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_purchase_price'),
                          controller: costPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cost / Purchase Price (₹)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          isExpanded: true,
                          value: selectedTaxRate,
                          decoration: const InputDecoration(
                            labelText: 'GST Slab',
                            border: OutlineInputBorder(),
                          ),
                          items: _gstSlabs.map((rate) {
                            return DropdownMenuItem(
                              value: rate,
                              child: Text(rate == 0 ? '0% (Exempt)' : '$rate%'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedTaxRate = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stock & Low Stock Reorder Threshold
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('input_product_stock'),
                          controller: stockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Current Stock ($selectedUnit)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Min Stock Alert Threshold',
                            hintText: 'Alert when stock falls below',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hsnCtrl,
                          decoration: const InputDecoration(
                            labelText: 'HSN / SAC Code',
                            hintText: 'e.g. 1006',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
                final minStock = double.tryParse(minStockCtrl.text.trim()) ?? 5.0;
                final barcode = barcodeCtrl.text.trim();
                final secBarcode = secBarcodeCtrl.text.trim();
                final sku = skuCtrl.text.trim();
                final variantName = variantCtrl.text.trim();
                final hsn = hsnCtrl.text.trim();

                if (name.isNotEmpty && sell > 0) {
                  final prodId = existing?.id ?? 'prod-${DateTime.now().millisecondsSinceEpoch}';
                  await widget.database.upsertProduct(
                    ProductsCompanion.insert(
                      id: prodId,
                      name: name,
                      variantName: Value(variantName.isNotEmpty ? variantName : null),
                      parentProductId: Value(selectedParentId),
                      barcode: Value(barcode.isNotEmpty ? barcode : null),
                      secondaryBarcode: Value(secBarcode.isNotEmpty ? secBarcode : null),
                      sku: Value(sku.isNotEmpty ? sku : null),
                      categoryId: Value(selectedCategoryId),
                      sellingPrice: sell,
                      purchasePrice: Value(cost),
                      stockQuantity: Value(stock),
                      unit: Value(selectedUnit),
                      taxRate: Value(selectedTaxRate),
                      hsnCode: Value(hsn.isNotEmpty ? hsn : null),
                      minStockAlert: Value(minStock),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  if (mounted) Navigator.of(ctx).pop();
                  await _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Quick Stock Adjustment Modal ---
  void _showQuickStockDialog(Product p) {
    final qtyCtrl = TextEditingController(text: '10');
    String reason = 'restock';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Adjust Stock: ${p.name} ${p.variantName != null ? "(${p.variantName})" : ""}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Available: ${p.stockQuantity} ${p.unit}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: reason,
                      decoration: const InputDecoration(labelText: 'Action Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'restock', child: Text('Add Stock (+ Restock)')),
                        DropdownMenuItem(value: 'damage', child: Text('Remove (- Damaged/Expired)')),
                        DropdownMenuItem(value: 'adjustment', child: Text('Inventory Count Audit')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => reason = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: reason == 'adjustment' ? 'New Total Count' : 'Delta Quantity',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
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
                final inputQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                if (inputQty > 0) {
                  double delta = inputQty;
                  if (reason == 'damage') {
                    delta = -inputQty;
                  } else if (reason == 'adjustment') {
                    delta = inputQty - p.stockQuantity;
                  }

                  await widget.database.applyInventoryDelta(
                    movementId: 'mov-${DateTime.now().millisecondsSinceEpoch}',
                    productId: p.id,
                    deltaQuantity: delta,
                    reason: reason,
                  );

                  if (mounted) Navigator.of(ctx).pop();
                  await _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Commit Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1-Click Thermal Barcode Sticker Print ---
  Future<void> _printBarcodeSticker(Product p) async {
    final displayName = p.variantName != null ? '${p.name} (${p.variantName})' : p.name;
    final barcodeToPrint = p.barcode ?? p.sku ?? p.id;

    await Printing.layoutPdf(
      onLayout: (format) async {
        return ShelfLabelGenerator.generateLabel(
          store: const LabelStoreInfo(storeName: 'WebotApp Store'),
          product: ProductLabelData(
            name: displayName,
            barcode: barcodeToPrint,
            sku: p.sku,
            sellingPrice: p.sellingPrice,
            unit: p.unit,
          ),
        );
      },
      name: 'Sticker_${p.name.replaceAll(" ", "_")}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFEF4444)),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load product catalog',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header & Action Buttons
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
                              'Manage items, pack sizes, barcodes, GST slabs, and inventory stock',
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
                            onPressed: _exportCatalog,
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            label: const Text('Export CSV'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _showCsvImportDialog,
                            icon: const Icon(Icons.file_upload_outlined, size: 18),
                            label: const Text('Import CSV'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _showAddCategoryDialog(),
                            icon: const Icon(Icons.category_outlined, size: 18),
                            label: const Text('Add Category'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 10),
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

                  // Batch Selection Banner (when items are selected)
                  if (_selectedProductIds.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedProductIds.length} products selected for batch operations',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E40AF), fontSize: 13),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _printBatchLabels,
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: Text('Print ${_selectedProductIds.length} Shelf Labels'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () => setState(() => _selectedProductIds.clear()),
                            child: const Text('Clear Selection'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Search input and Category Chips Bar
                  Row(
                    children: [
                      // Search input
                      Container(
                        width: 360,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Search by name, variant, barcode, or SKU...',
                            prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Category & Low Stock Filter Chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text('All (${_allProducts.length})'),
                                selected: _selectedCategoryFilter == null && !_filterLowStockOnly,
                                onSelected: (_) => setState(() {
                                  _selectedCategoryFilter = null;
                                  _filterLowStockOnly = false;
                                }),
                                selectedColor: const Color(0xFFDCFCE7),
                                checkmarkColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              const SizedBox(width: 8),

                              // Low stock filter chip
                              FilterChip(
                                label: Text('⚠️ Low Stock ($_lowStockCount)'),
                                selected: _filterLowStockOnly,
                                onSelected: (val) => setState(() {
                                  _filterLowStockOnly = val;
                                  if (val) _selectedCategoryFilter = null;
                                }),
                                selectedColor: const Color(0xFFFEF2F2),
                                checkmarkColor: const Color(0xFFDC2626),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              const SizedBox(width: 8),

                              ..._categories.map((c) {
                                final count = _allProducts.where((p) => p.categoryId == c.id).length;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: FilterChip(
                                    label: Text('${c.name} ($count)'),
                                    selected: _selectedCategoryFilter == c.id && !_filterLowStockOnly,
                                    onSelected: (_) => setState(() {
                                      _selectedCategoryFilter = c.id;
                                      _filterLowStockOnly = false;
                                    }),
                                    selectedColor: const Color(0xFFDCFCE7),
                                    checkmarkColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              return _buildTableHeader(products);
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

  Widget _buildTableHeader(List<Product> products) {
    final allSelected = products.isNotEmpty && products.every((p) => _selectedProductIds.contains(p.id));

    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedProductIds.addAll(products.map((p) => p.id));
                } else {
                  _selectedProductIds.clear();
                }
              });
            },
          ),
          const SizedBox(width: 8),
          const Expanded(flex: 3, child: Text('Product & Pack Size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 2, child: Text('Barcodes / SKU', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 2, child: Text('Category & Tax', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 2, child: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 2, child: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 2, child: Text('Stock Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)))),
          const Expanded(flex: 4, child: Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    final catName = _categories.where((c) => c.id == p.categoryId).map((c) => c.name).firstOrNull ?? '-';
    final isLowStock = p.stockQuantity <= p.minStockAlert;
    final isSelected = _selectedProductIds.contains(p.id);

    return Container(
      color: isSelected ? const Color(0xFFF0FDF4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedProductIds.add(p.id);
                } else {
                  _selectedProductIds.remove(p.id);
                }
              });
            },
          ),
          const SizedBox(width: 8),

          // Product Name & Variant Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.variantName != null && p.variantName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                p.variantName!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (p.parentProductId != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 2.0),
                          child: Text(
                            '↳ Linked pack-size variant',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Barcodes & SKU
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      p.barcode ?? '-',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                if (p.secondaryBarcode != null && p.secondaryBarcode!.isNotEmpty)
                  Text(
                    'Alt: ${p.secondaryBarcode}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                  ),
                if (p.sku != null && p.sku!.isNotEmpty)
                  Text(
                    'SKU: ${p.sku!}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),

          // Category & Tax
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  catName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                Text(
                  p.taxRate == 0 ? '0% GST' : '${p.taxRate}% GST',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Selling Price
          Expanded(
            flex: 2,
            child: Text(
              '₹${p.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),

          // Purchase Price
          Expanded(
            flex: 2,
            child: Text(
              p.purchasePrice != null ? '₹${p.purchasePrice!.toStringAsFixed(2)}' : '-',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),

          // Stock Level & Low Stock Chip
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${p.stockQuantity} ${p.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF334155),
                  ),
                ),
                if (isLowStock)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      'Low Stock',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                  ),
              ],
            ),
          ),

          // Status Badge
          Expanded(
            flex: 1,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: p.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),

          // Quick Actions (Print Sticker, Quick Restock, Edit, Toggle)
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF0284C7)),
                  tooltip: 'Print Thermal Barcode Sticker',
                  onPressed: () => _printBarcodeSticker(p),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Color(0xFF10B981)),
                  tooltip: 'Quick Restock / Stock Adjust',
                  onPressed: () => _showQuickStockDialog(p),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Edit Product & Pack Size',
                  onPressed: () => _showProductDialog(p),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

import 'dart:async';
import 'dart:io';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Product Expiry & Shelf-Life Management Console for Store Managers.
/// Enables store staff to identify products expiring within 1 month down to 1 day,
/// apply clearance markdowns, or log waste write-offs.
class ExpiryTrackerScreen extends StatefulWidget {
  final AppDatabase database;

  const ExpiryTrackerScreen({super.key, required this.database});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> {
  List<Product> _allProductsWithExpiry = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _selectedCategoryId;
  String _filterMode = 'all'; // 'all', 'expired', '7_days', '30_days'
  final Set<String> _selectedProductIds = {};

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prods = await widget.database.getExpiringProducts(days: 3650);
      final cats = await widget.database.getAllCategories();
      if (mounted) {
        setState(() {
          _allProductsWithExpiry = prods;
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expiry data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _allProductsWithExpiry.where((p) {
      if (p.expiryDate == null) return false;
      final exp = DateTime(p.expiryDate!.year, p.expiryDate!.month, p.expiryDate!.day);
      final diffDays = exp.difference(today).inDays;

      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }

      if (_filterMode == 'expired' && diffDays >= 0) return false;
      if (_filterMode == '7_days' && (diffDays < 0 || diffDays > 7)) return false;
      if (_filterMode == '30_days' && (diffDays < 0 || diffDays > 30)) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = p.name.toLowerCase();
        final barcode = p.barcode?.toLowerCase() ?? '';
        final sku = p.sku?.toLowerCase() ?? '';
        final batch = p.batchNumber?.toLowerCase() ?? '';
        return name.contains(q) || barcode.contains(q) || sku.contains(q) || batch.contains(q);
      }

      return true;
    }).toList();
  }

  int get _expiredCount {
    final today = DateTime.now();
    return _allProductsWithExpiry.where((p) => p.expiryDate != null && p.expiryDate!.isBefore(today)).length;
  }

  int get _expiring7DaysCount {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 7));
    return _allProductsWithExpiry.where((p) => p.expiryDate != null && p.expiryDate!.isAfter(now) && p.expiryDate!.isBefore(cutoff)).length;
  }

  int get _expiring30DaysCount {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 30));
    return _allProductsWithExpiry.where((p) => p.expiryDate != null && p.expiryDate!.isAfter(now) && p.expiryDate!.isBefore(cutoff)).length;
  }

  double get _expiredStockValue {
    final now = DateTime.now();
    double total = 0.0;
    for (final p in _allProductsWithExpiry) {
      if (p.expiryDate != null && p.expiryDate!.isBefore(now)) {
        total += (p.stockQuantity * p.sellingPrice);
      }
    }
    return total;
  }

  void _showMarkdownDialog(Product product) {
    final currentPrice = product.sellingPrice;
    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(2));
    double calculatedDiscount = 0.0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_offer_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clearance Markdown Discount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(
                      'Promote near-expiry stock: ${product.name}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Original Selling Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('₹ ${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Stock on Hand', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text('${product.stockQuantity.toStringAsFixed(0)} ${product.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('One-Tap Discount Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final pct in [10, 20, 30, 50])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(
                            onPressed: () {
                              final newP = (currentPrice * (1.0 - (pct / 100))).clamp(1.0, currentPrice);
                              setDialogState(() {
                                calculatedDiscount = pct.toDouble();
                                priceCtrl.text = newP.toStringAsFixed(2);
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              backgroundColor: calculatedDiscount == pct ? const Color(0xFFEFF6FF) : null,
                              side: BorderSide(color: calculatedDiscount == pct ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                            ),
                            child: Text('-$pct%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'New Markdown Selling Price',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPrice = double.tryParse(priceCtrl.text.trim());
                if (newPrice != null && newPrice > 0) {
                  await (widget.database.update(widget.database.products)..where((t) => t.id.equals(product.id))).write(
                    ProductsCompanion(
                      sellingPrice: Value(newPrice),
                      updatedAt: Value(DateTime.now()),
                    ),
                  );

                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Markdown applied! "${product.name}" price updated to ₹${newPrice.toStringAsFixed(2)}'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    await _loadData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Apply Markdown Price'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWriteOffDialog(Product product) {
    final disposeQtyCtrl = TextEditingController(text: product.stockQuantity.toInt().toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Write-Off Expired Stock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to write off and discard stock for "${product.name}"?',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: disposeQtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity to Discard',
                  suffixText: product.unit,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will reduce product inventory to 0 and record an inventory movement with reason "expired_waste".',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(disposeQtyCtrl.text.trim()) ?? product.stockQuantity;
              if (qty > 0) {
                await widget.database.recordStockAdjustment(
                  productId: product.id,
                  deltaQuantity: -qty,
                  reason: 'expired_waste',
                );

                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logged waste write-off of $qty ${product.unit} for "${product.name}"'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  await _loadData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Write-Off'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkWriteOff() {
    final count = _selectedProductIds.length;
    if (count == 0) return;

    final selected = _allProductsWithExpiry.where((p) => _selectedProductIds.contains(p.id)).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Text('Bulk Write-Off $count Products?'),
          ],
        ),
        content: Text(
          'Are you sure you want to write off and discard all on-hand stock for $count selected products? Stock levels will be reduced to 0 and waste disposal will be logged in the audit trail.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              for (final p in selected) {
                if (p.stockQuantity > 0) {
                  await widget.database.applyInventoryDelta(
                    movementId: 'writeoff-${DateTime.now().microsecondsSinceEpoch}-${p.id}',
                    productId: p.id,
                    deltaQuantity: -p.stockQuantity,
                    reason: 'waste_write_off',
                    referenceId: 'bulk_expiry_discard',
                  );
                }
              }
              _selectedProductIds.clear();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Successfully logged waste write-off for $count products'),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Confirm Write-Off ($count)'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDeleteExpiryItems() {
    final count = _selectedProductIds.length;
    if (count == 0) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Text('Permanently Delete $count Products?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete $count selected products from the store catalog? All inventory movements will be deleted and this action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final toDelete = _selectedProductIds.toList();
              await widget.database.bulkDeleteProducts(toDelete);
              _selectedProductIds.clear();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Successfully purged $count products from catalog'),
                    backgroundColor: const Color(0xFF0F172A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Delete $count Products'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportShelfPullCsv() async {
    HapticFeedback.lightImpact();
    final items = _filteredProducts;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expiring items to export'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Variant,Barcode,SKU,Batch No,Expiry Date,Days Remaining,Stock,Unit,Current Price');

      final now = DateTime.now();
      for (final p in items) {
        final days = p.expiryDate!.difference(now).inDays;
        final expStr = _dateFormat.format(p.expiryDate!);
        buffer.writeln(
          '"${p.name.replaceAll('"', '""')}","${(p.variantName ?? '').replaceAll('"', '""')}",${p.barcode ?? ''},${p.sku ?? ''},"${p.batchNumber ?? ''}",$expStr,$days,${p.stockQuantity},${p.unit},${p.sellingPrice}',
        );
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(docsDir.path, 'Shelf_Pull_Expiry_List_$dateStr.csv'));
      await outFile.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expiry pull list exported: ${outFile.path}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        'Product Expiry & Shelf-Life Tracker',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track expiring items, enforce FIFO rotation, apply clearance markdowns, or log waste write-offs.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportShelfPullCsv,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Shelf-Pull CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh Expiry Data',
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 KPI Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Expired Products',
                    value: '$_expiredCount items',
                    subtitle: 'Loss value: ${_currencyFormat.format(_expiredStockValue)}',
                    icon: Icons.dangerous_rounded,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Expiring in 7 Days',
                    value: '$_expiring7DaysCount items',
                    subtitle: 'Immediate clearance candidate',
                    icon: Icons.hourglass_bottom_rounded,
                    color: const Color(0xFFF97316),
                    bgColor: const Color(0xFFFFF7ED),
                    borderColor: const Color(0xFFFED7AA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Expiring in 1 Month',
                    value: '$_expiring30DaysCount items',
                    subtitle: 'Shift to front display (FIFO)',
                    icon: Icons.event_note_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Tracked with Expiry',
                    value: '${_allProductsWithExpiry.length} items',
                    subtitle: 'Active perishable catalog',
                    icon: Icons.verified_user_outlined,
                    color: const Color(0xFF0F172A),
                    bgColor: const Color(0xFFF1F5F9),
                    borderColor: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Filter & Search Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (val) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 150), () {
                          if (mounted) setState(() => _searchQuery = val.trim());
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search product, barcode, or batch no...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filter Category',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                        ..._categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Segmented Filter
                  Row(
                    children: [
                      _buildFilterChip('All (${_allProductsWithExpiry.length})', 'all'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Expired ($_expiredCount)', 'expired', isRed: true),
                      const SizedBox(width: 6),
                      _buildFilterChip('≤ 7 Days ($_expiring7DaysCount)', '7_days', isOrange: true),
                      const SizedBox(width: 6),
                      _buildFilterChip('≤ 30 Days ($_expiring30DaysCount)', '30_days', isAmber: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Batch Selection Banner (when expiring items are selected)
            if (_selectedProductIds.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${_selectedProductIds.length} expiring item(s) selected',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B), fontSize: 13),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _confirmBulkWriteOff,
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: Text('Bulk Write-Off (${_selectedProductIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _confirmBulkDeleteExpiryItems,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: Text('Delete from Catalog (${_selectedProductIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
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

            // Expiry Table View
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_available_rounded, size: 48, color: Color(0xFF10B981)),
                                const SizedBox(height: 12),
                                const Text('No Items Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Text(
                                  _allProductsWithExpiry.isEmpty
                                      ? 'No products have expiry dates assigned yet. Edit products to configure shelf-life dates.'
                                      : 'No products match the selected criteria.',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final p = products[index];
                              return _buildProductRow(p);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(p.expiryDate!.year, p.expiryDate!.month, p.expiryDate!.day);
    final diffDays = expDate.difference(today).inDays;

    final isExpired = diffDays < 0;
    final isWithin7Days = !isExpired && diffDays <= 7;
    final isWithin30Days = !isExpired && diffDays > 7 && diffDays <= 30;

    final badgeColor = isExpired
        ? const Color(0xFFDC2626)
        : isWithin7Days
            ? const Color(0xFFEA580C)
            : isWithin30Days
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A);

    final badgeBg = isExpired
        ? const Color(0xFFFEF2F2)
        : isWithin7Days
            ? const Color(0xFFFFF7ED)
            : isWithin30Days
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF0FDF4);

    final badgeText = isExpired
        ? 'EXPIRED (${diffDays.abs()}d AGO)'
        : diffDays == 0
            ? 'EXPIRES TODAY'
            : isWithin7Days
                ? 'EXPIRES IN $diffDays DAYS'
                : isWithin30Days
                    ? 'EXPIRES IN $diffDays DAYS'
                    : '$diffDays DAYS LEFT';

    final isSelected = _selectedProductIds.contains(p.id);

    return RepaintBoundary(
      key: ValueKey('expiry_row_${p.id}'),
      child: Container(
        color: isSelected ? const Color(0xFFFEF2F2) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
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
          ),
          const SizedBox(width: 8),
          // Product name and batch
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.variantName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.variantName!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (p.batchNumber != null && p.batchNumber!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text('Batch: ${p.batchNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (p.barcode != null)
                      Flexible(
                        child: Text(
                          '${p.barcode}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Stock on Hand
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stock on Hand:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                Text(
                  '${p.stockQuantity.toStringAsFixed(p.stockQuantity.truncateToDouble() == p.stockQuantity ? 0 : 1)} ${p.unit}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Expiry Date Column
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expiry Date:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                Text(
                  _dateFormat.format(p.expiryDate!),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Countdown Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withOpacity(0.3)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 16),

          // Current Selling Price
          SizedBox(
            width: 85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Price:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                Text(
                  '₹${p.sellingPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Actions
          if (!isExpired)
            OutlinedButton.icon(
              onPressed: () => _showMarkdownDialog(p),
              icon: const Icon(Icons.local_offer_outlined, size: 15),
              label: const Text('Markdown'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFFCD34D)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showWriteOffDialog(p),
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Write-Off'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildFilterChip(String label, String value, {bool isRed = false, bool isOrange = false, bool isAmber = false}) {
    final isSelected = _filterMode == value;
    Color activeColor = const Color(0xFF10B981);
    if (isRed) activeColor = const Color(0xFFEF4444);
    if (isOrange) activeColor = const Color(0xFFF97316);
    if (isAmber) activeColor = const Color(0xFFD97706);

    return InkWell(
      onTap: () => setState(() => _filterMode = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


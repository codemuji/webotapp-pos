import 'dart:io';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Low Stock & Replenishment Console for Store Managers.
/// Provides visibility into inventory depletion, safety thresholds, and 1-click restock operations.
class LowStockScreen extends StatefulWidget {
  final AppDatabase database;

  const LowStockScreen({super.key, required this.database});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  List<Product> _lowStockProducts = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategoryId;
  String _statusFilter = 'all'; // 'all', 'out_of_stock', 'critical'

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prods = await widget.database.getLowStockProducts();
      final cats = await widget.database.getAllCategories();
      if (mounted) {
        setState(() {
          _lowStockProducts = prods;
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading low stock data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    return _lowStockProducts.where((p) {
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_statusFilter == 'out_of_stock' && p.stockQuantity > 0) {
        return false;
      }
      if (_statusFilter == 'critical' && (p.stockQuantity == 0 || p.stockQuantity > (p.minStockAlert / 2))) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = p.name.toLowerCase();
        final barcode = p.barcode?.toLowerCase() ?? '';
        final sku = p.sku?.toLowerCase() ?? '';
        final variant = p.variantName?.toLowerCase() ?? '';
        return name.contains(q) || barcode.contains(q) || sku.contains(q) || variant.contains(q);
      }
      return true;
    }).toList();
  }

  int get _outOfStockCount => _lowStockProducts.where((p) => p.stockQuantity <= 0).length;
  int get _criticalCount => _lowStockProducts.where((p) => p.stockQuantity > 0 && p.stockQuantity <= (p.minStockAlert / 2)).length;
  int get _warningCount => _lowStockProducts.where((p) => p.stockQuantity > (p.minStockAlert / 2) && p.stockQuantity <= p.minStockAlert).length;

  double get _estimatedRestockCost {
    double total = 0.0;
    for (final p in _lowStockProducts) {
      final targetBuffer = p.minStockAlert * 2;
      final deficit = (targetBuffer - p.stockQuantity).clamp(0.0, 99999.0);
      final unitCost = p.purchasePrice ?? (p.sellingPrice * 0.75);
      total += (deficit * unitCost);
    }
    return total;
  }

  void _showQuickRestockDialog(Product product) {
    final restockQtyCtrl = TextEditingController(text: '${(product.minStockAlert * 2 - product.stockQuantity).clamp(1.0, 99999.0).toInt()}');
    final costPriceCtrl = TextEditingController(
      text: product.purchasePrice != null ? product.purchasePrice!.toStringAsFixed(2) : '',
    );
    bool isSaving = false;

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
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Restock Inventory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(
                      product.name + (product.variantName != null ? ' (${product.variantName})' : ''),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current stock status banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: product.stockQuantity <= 0 ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: product.stockQuantity <= 0 ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Current Stock: ${product.stockQuantity.toStringAsFixed(product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2)} ${product.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: product.stockQuantity <= 0 ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Threshold: ${product.minStockAlert.toStringAsFixed(0)} ${product.unit}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Quantity to Add / Restock:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: restockQtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    suffixText: product.unit,
                    border: const OutlineInputBorder(),
                    hintText: 'e.g. 20',
                  ),
                ),
                const SizedBox(height: 8),
                // Quick chips
                Wrap(
                  spacing: 6,
                  children: [
                    const Text('Quick Add: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    for (final addQty in [5, 10, 25, 50, 100])
                      InkWell(
                        onTap: () {
                          final cur = double.tryParse(restockQtyCtrl.text) ?? 0.0;
                          restockQtyCtrl.text = (cur + addQty).toInt().toString();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '+$addQty',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: costPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Purchase / Cost Price (Optional)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    hintText: 'Leave unchanged if same',
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
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      final addQty = double.tryParse(restockQtyCtrl.text.trim());
                      if (addQty == null || addQty <= 0) return;

                      setDialogState(() => isSaving = true);
                      final newCost = double.tryParse(costPriceCtrl.text.trim());

                      await widget.database.recordStockAdjustment(
                        productId: product.id,
                        deltaQuantity: addQty,
                        reason: 'restock',
                      );

                      if (newCost != null && newCost > 0) {
                        await (widget.database.update(widget.database.products)..where((t) => t.id.equals(product.id))).write(
                          ProductsCompanion(purchasePrice: Value(newCost)),
                        );
                      }

                      if (mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully restocked +$addQty ${product.unit} of "${product.name}"'),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        await _loadData();
                      }
                    },
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Confirm Restock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReorderCsv() async {
    HapticFeedback.lightImpact();
    final items = _filteredProducts;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No low-stock items to export'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Variant,Barcode,SKU,Category,Current Stock,Min Threshold,Suggested Reorder,Unit,Est Cost (INR)');

      for (final p in items) {
        final catName = _categories.where((c) => c.id == p.categoryId).map((c) => c.name).firstOrNull ?? '-';
        final suggested = (p.minStockAlert * 2 - p.stockQuantity).clamp(1.0, 99999.0);
        final cost = p.purchasePrice ?? (p.sellingPrice * 0.75);
        final estTotal = (suggested * cost).toStringAsFixed(2);

        buffer.writeln(
          '"${p.name.replaceAll('"', '""')}","${(p.variantName ?? '').replaceAll('"', '""')}",${p.barcode ?? ''},${p.sku ?? ''},"$catName",${p.stockQuantity},${p.minStockAlert},$suggested,${p.unit},$estTotal',
        );
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(docsDir.path, 'Low_Stock_Reorder_$dateStr.csv'));
      await outFile.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reorder order sheet exported to: ${outFile.path}'),
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
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Low Stock & Replenishment Console',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Monitor inventory depletion, manage safety thresholds, and execute 1-click restock operations.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportReorderCsv,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Reorder CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh Inventory',
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
                    title: 'Out of Stock',
                    value: '$_outOfStockCount',
                    subtitle: 'Immediate sales loss',
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Critical Stock',
                    value: '$_criticalCount',
                    subtitle: '< 50% safety buffer',
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFF97316),
                    bgColor: const Color(0xFFFFF7ED),
                    borderColor: const Color(0xFFFED7AA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Low Stock Items',
                    value: '${_lowStockProducts.length}',
                    subtitle: 'At or below threshold',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Est. Restock Cost',
                    value: _currencyFormat.format(_estimatedRestockCost),
                    subtitle: 'To achieve 2x safety buffer',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF0F172A),
                    bgColor: const Color(0xFFF1F5F9),
                    borderColor: const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Filter & Search Controls
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
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Search product name, SKU, or barcode...',
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
                  // Segmented Status Filter
                  Row(
                    children: [
                      _buildFilterChip('All Low (${_lowStockProducts.length})', 'all'),
                      const SizedBox(width: 6),
                      _buildFilterChip('Out of Stock ($_outOfStockCount)', 'out_of_stock', isRed: true),
                      const SizedBox(width: 6),
                      _buildFilterChip('Critical ($_criticalCount)', 'critical', isOrange: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Table View
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
                                const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                                const SizedBox(height: 12),
                                const Text('No Low Stock Items Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Text(
                                  _lowStockProducts.isEmpty
                                      ? 'All active catalog items are above their minimum stock thresholds.'
                                      : 'No items match the selected search or filter criteria.',
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
    final catName = _categories.where((c) => c.id == p.categoryId).map((c) => c.name).firstOrNull ?? '-';
    final isOut = p.stockQuantity <= 0;
    final isCritical = !isOut && p.stockQuantity <= (p.minStockAlert / 2);
    final suggestedReorder = (p.minStockAlert * 2 - p.stockQuantity).clamp(1.0, 99999.0).toInt();

    final statusColor = isOut
        ? const Color(0xFFDC2626)
        : isCritical
            ? const Color(0xFFEA580C)
            : const Color(0xFFD97706);

    final statusBg = isOut
        ? const Color(0xFFFEF2F2)
        : isCritical
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFFFFBEB);

    final statusText = isOut
        ? 'OUT OF STOCK'
        : isCritical
            ? 'CRITICAL DEFICIT'
            : 'LOW STOCK';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Product name and sku
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
                    Text('Cat: $catName', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    if (p.barcode != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '• ${p.barcode}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Stock Gauge Bar (Current vs Threshold)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.stockQuantity.toStringAsFixed(p.stockQuantity.truncateToDouble() == p.stockQuantity ? 0 : 1)} ${p.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      'Threshold: ${p.minStockAlert.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.minStockAlert > 0 ? (p.stockQuantity / p.minStockAlert).clamp(0.0, 1.0) : 0.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 16),

          // Suggested Reorder
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Suggested Order:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                Text(
                  '+$suggestedReorder ${p.unit}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Quick Restock Button
          ElevatedButton.icon(
            onPressed: () => _showQuickRestockDialog(p),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Restock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isRed = false, bool isOrange = false}) {
    final isSelected = _statusFilter == value;
    Color activeColor = const Color(0xFF10B981);
    if (isRed) activeColor = const Color(0xFFEF4444);
    if (isOrange) activeColor = const Color(0xFFF97316);

    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
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
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


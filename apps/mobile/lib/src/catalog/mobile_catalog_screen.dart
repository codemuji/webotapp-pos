import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cart/cart_state.dart';
import '../providers.dart';
import '../sync/sync_coordinator.dart';
import '../sync/sync_status_sheet.dart';
import '../sync/terminal_pairing_screen.dart';
import '../sync/terminal_storage.dart';
import '../theme/webotapp_logo.dart';
import '../widgets/tactile_button.dart';

/// Full-screen mobile product catalog browser allowing cashiers to view synced
/// products, search by name/SKU/barcode, filter by categories, and add items to cart.
class MobileCatalogScreen extends ConsumerStatefulWidget {
  final AppDatabase database;
  final SyncCoordinator syncCoordinator;
  final TerminalStorage terminalStorage;
  final bool isActiveTab;

  const MobileCatalogScreen({
    super.key,
    required this.database,
    required this.syncCoordinator,
    required this.terminalStorage,
    this.isActiveTab = true,
  });

  @override
  ConsumerState<MobileCatalogScreen> createState() => _MobileCatalogScreenState();
}

class _MobileCatalogScreenState extends ConsumerState<MobileCatalogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MobileCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prods = await widget.database.getActiveProducts();
      final cats = await widget.database.getAllCategories();
      if (mounted) {
        setState(() {
          _allProducts = prods;
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _triggerSync() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    try {
      final res = await widget.syncCoordinator.runSync();
      await _loadData();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.state == SyncState.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _allProducts.where((p) {
      final matchesCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      if (!matchesCat) return false;
      if (query.isEmpty) return true;
      final name = p.name.toLowerCase();
      final barcode = p.barcode?.toLowerCase() ?? '';
      final sku = p.sku?.toLowerCase() ?? '';
      return name.contains(query) || barcode.contains(query) || sku.contains(query);
    }).toList();
  }

  void _addToCart(Product product) {
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).addItem(
          productId: product.id,
          productName: product.name,
          unitPrice: Decimal.parse(product.sellingPrice.toString()),
          barcode: product.barcode,
          unit: product.unit,
        );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${product.name}" to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(catalogRevisionProvider, (_, __) => _loadData());
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const WebotAppLogo(
          markSize: 22,
          fontSize: 16,
          subtitle: 'Store Catalog',
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sync Status',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: () {
              showSyncStatusSheet(
                context: context,
                coordinator: widget.syncCoordinator,
                storage: widget.terminalStorage,
                onNavigateToCatalog: _loadData,
                onPairNewServer: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TerminalPairingScreen(
                        storage: widget.terminalStorage,
                        pairingClient: ref.read(pairingClientProvider),
                        syncCoordinator: widget.syncCoordinator,
                        onNavigateToCatalog: _loadData,
                      ),
                    ),
                  );
                },
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search products by name, SKU, or barcode...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip(null, 'All (${_allProducts.length})'),
                        for (final cat in _categories)
                          _buildCategoryChip(cat.id, cat.name),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? _buildEmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = products[index];
                          return _buildProductCard(p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? catId, String label) {
    final isSelected = _selectedCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = isSelected ? null : catId;
          });
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Text(
              _allProducts.isEmpty ? 'No Products in Local Database' : 'No matching products',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              _allProducts.isEmpty
                  ? 'Connect to the desktop admin node and sync the catalog.'
                  : 'Try searching with a different keyword or category.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            if (_allProducts.isEmpty) ...[
              const SizedBox(height: 24),
              TactileButton(
                onPressed: _triggerSync,
                minHeight: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Sync Catalog Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${p.sellingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      ' / ${p.unit}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 12),
                    if (p.barcode != null && p.barcode!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.barcode!,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TactileButton(
            onPressed: () => _addToCart(p),
            minHeight: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

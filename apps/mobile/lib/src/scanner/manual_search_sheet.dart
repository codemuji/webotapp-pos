import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cart/cart_state.dart';
import '../widgets/tactile_button.dart';

/// Opens the manual product search modal bottom sheet for rapid item lookups.
Future<void> showManualProductSearchSheet({
  required BuildContext context,
  required AppDatabase database,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ManualProductSearchContent(database: database),
  );
}

class _ManualProductSearchContent extends ConsumerStatefulWidget {
  final AppDatabase database;

  const _ManualProductSearchContent({required this.database});

  @override
  ConsumerState<_ManualProductSearchContent> createState() => _ManualProductSearchContentState();
}

class _ManualProductSearchContentState extends ConsumerState<_ManualProductSearchContent> {
  final _searchController = TextEditingController();
  List<Product> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    setState(() => _isLoading = true);
    final products = await widget.database.getActiveProducts();
    if (mounted) {
      setState(() {
        _results = products;
        _isLoading = false;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _loadInitialProducts();
      return;
    }

    setState(() => _isLoading = true);
    final results = await widget.database.searchProducts(trimmed);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _onProductSelected(Product product) {
    ref.read(cartProvider.notifier).addItem(
          productId: product.id,
          productName: product.name,
          unitPrice: Decimal.parse(product.sellingPrice.toString()),
          barcode: product.barcode,
          unit: product.unit,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search Product Catalog',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TactileButton(
                  minWidth: 36,
                  minHeight: 36,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or barcode...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadInitialProducts();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final product = _results[index];
                          return TactileButton(
                            key: Key('search_result_${product.id}'),
                            minHeight: 64,
                            onPressed: () => _onProductSelected(product),
                            child: Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (product.barcode != null)
                                          Text(
                                            'Barcode: ${product.barcode}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${product.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

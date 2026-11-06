import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../catalog/csv_catalog_service.dart';
import 'desktop_receipt_generator.dart';
import 'invoice_detail_dialog.dart';

/// Screen displaying all synced sales transactions, line item details, discounts/offers,
/// and allowing instant receipt generation and printing for the desktop store owner.
class SalesTransactionsScreen extends StatefulWidget {
  final AppDatabase database;

  const SalesTransactionsScreen({
    super.key,
    required this.database,
  });

  @override
  State<SalesTransactionsScreen> createState() => _SalesTransactionsScreenState();
}

class _SalesTransactionsScreenState extends State<SalesTransactionsScreen> {
  List<InvoiceWithItems> _allSales = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedDateFilter = 'all'; // all, today, yesterday, 7days, 30days
  String _selectedPaymentFilter = 'all'; // all, cash, upi_qr, card

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoices = await widget.database.getAllInvoices();
      final List<InvoiceWithItems> list = [];
      for (final inv in invoices) {
        final items = await widget.database.getInvoiceItems(inv.id);
        list.add(InvoiceWithItems(invoice: inv, items: items));
      }

      if (mounted) {
        setState(() {
          _allSales = list;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading sales: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<InvoiceWithItems> get _filteredSales {
    var list = _allSales;
    final now = DateTime.now();

    // 1. Date filter
    if (_selectedDateFilter == 'today') {
      final startOfToday = DateTime(now.year, now.month, now.day);
      list = list.where((s) => s.invoice.createdAt.isAfter(startOfToday)).toList();
    } else if (_selectedDateFilter == 'yesterday') {
      final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
      final endOfYesterday = DateTime(now.year, now.month, now.day);
      list = list.where((s) => s.invoice.createdAt.isAfter(startOfYesterday) && s.invoice.createdAt.isBefore(endOfYesterday)).toList();
    } else if (_selectedDateFilter == '7days') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      list = list.where((s) => s.invoice.createdAt.isAfter(sevenDaysAgo)).toList();
    } else if (_selectedDateFilter == '30days') {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      list = list.where((s) => s.invoice.createdAt.isAfter(thirtyDaysAgo)).toList();
    }

    // 2. Payment filter
    if (_selectedPaymentFilter != 'all') {
      list = list.where((s) => s.invoice.paymentMethod.toLowerCase() == _selectedPaymentFilter.toLowerCase()).toList();
    }

    // 3. Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final invMatch = s.invoice.invoiceNumber.toLowerCase().contains(q);
        final terminalMatch = s.invoice.deviceId.toLowerCase().contains(q);
        final cashierMatch = s.invoice.employeeId.toLowerCase().contains(q);
        final itemMatch = s.items.any((i) => i.productName.toLowerCase().contains(q) || (i.barcode != null && i.barcode!.toLowerCase().contains(q)));
        return invMatch || terminalMatch || cashierMatch || itemMatch;
      }).toList();
    }

    return list;
  }

  // Aggregate Metrics for Header
  double get _totalRevenue => _filteredSales.fold<double>(0.0, (sum, s) => sum + s.invoice.totalAmount);
  double get _totalDiscounts => _filteredSales.fold<double>(0.0, (sum, s) => sum + s.invoice.discount);
  double get _totalTax => _filteredSales.fold<double>(0.0, (sum, s) => sum + s.invoice.taxAmount);
  int get _totalItemsSold => _filteredSales.fold<int>(0, (sum, s) => sum + s.items.length);

  Future<void> _exportSalesCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Invoice Number,Date,Terminal,Cashier,Payment Method,Subtotal,Discount,Tax,Total Amount,Item Count,Items');

    for (final sale in _filteredSales) {
      final inv = sale.invoice;
      final itemsSummary = sale.items.map((i) => '${i.productName} (x${i.quantity})').join('; ');
      buffer.writeln(
        '"${inv.invoiceNumber}","${inv.createdAt.toIso8601String()}","${inv.deviceId}","${inv.employeeId}","${inv.paymentMethod}",${inv.subtotal},${inv.discount},${inv.taxAmount},${inv.totalAmount},${sale.items.length},"$itemsSummary"',
      );
    }

    final file = await CsvCatalogService.saveCsvToFile('sales_transactions_export', buffer.toString());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales history exported to: ${file.path}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSales;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text('Error loading sales: $_errorMessage'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadSales, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sales & Invoices History',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Live sales synced from mobile POS terminals with itemised breakdowns and receipts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _loadSales,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Refresh'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: filtered.isEmpty ? null : _exportSalesCsv,
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: const Text('Export CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Metric Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Filtered Orders',
                              value: '${filtered.length}',
                              subtitle: '$_totalItemsSold items sold',
                              icon: Icons.receipt_long_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Revenue',
                              value: '₹${_totalRevenue.toStringAsFixed(2)}',
                              subtitle: filtered.isNotEmpty ? 'AOV: ₹${(_totalRevenue / filtered.length).toStringAsFixed(2)}' : 'AOV: ₹0.00',
                              icon: Icons.currency_rupee_rounded,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Discounts / Offers',
                              value: '₹${_totalDiscounts.toStringAsFixed(2)}',
                              subtitle: 'Customer savings given',
                              icon: Icons.local_offer_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'GST Collected',
                              value: '₹${_totalTax.toStringAsFixed(2)}',
                              subtitle: 'Total tax liability',
                              icon: Icons.account_balance_outlined,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Search & Filters Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Search field
                            Expanded(
                              flex: 3,
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText: 'Search by invoice #, product name, cashier, or terminal...',
                                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Date Filter Dropdown
                            DropdownButton<String>(
                              value: _selectedDateFilter,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Dates')),
                                DropdownMenuItem(value: 'today', child: Text('Today')),
                                DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                                DropdownMenuItem(value: '7days', child: Text('Last 7 Days')),
                                DropdownMenuItem(value: '30days', child: Text('Last 30 Days')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDateFilter = val);
                              },
                            ),
                            const SizedBox(width: 16),

                            // Payment Filter Dropdown
                            DropdownButton<String>(
                              value: _selectedPaymentFilter,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Payments')),
                                DropdownMenuItem(value: 'cash', child: Text('Cash Only')),
                                DropdownMenuItem(value: 'upi_qr', child: Text('UPI QR')),
                                DropdownMenuItem(value: 'card', child: Text('Card')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPaymentFilter = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sales Data Table
                      if (filtered.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(48),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFCBD5E1)),
                              const SizedBox(height: 16),
                              const Text(
                                'No Sales Transactions Found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Sales completed on your mobile terminals automatically sync here after checkout.',
                                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 18,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 13),
                              dataTextStyle: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              columns: const [
                                DataColumn(label: Text('Invoice #')),
                                DataColumn(label: Text('Date & Time')),
                                DataColumn(label: Text('Terminal / Cashier')),
                                DataColumn(label: Text('Items'), numeric: true),
                                DataColumn(label: Text('Subtotal'), numeric: true),
                                DataColumn(label: Text('Offer / Disc'), numeric: true),
                                DataColumn(label: Text('Total Amount'), numeric: true),
                                DataColumn(label: Text('Payment')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((sale) {
                                final inv = sale.invoice;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        inv.invoiceNumber,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    DataCell(Text(_dateFormat.format(inv.createdAt))),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text('${inv.deviceId} (${inv.employeeId})', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${sale.items.length} items',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('₹${inv.subtotal.toStringAsFixed(2)}')),
                                    DataCell(
                                      inv.discount > 0
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '-₹${inv.discount.toStringAsFixed(2)}',
                                                style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${inv.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                    DataCell(_buildPaymentBadge(inv.paymentMethod)),
                                    DataCell(_buildStatusBadge(inv.syncStatus)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () => showInvoiceDetailDialog(
                                              context: context,
                                              invoiceWithItems: sale,
                                            ),
                                            tooltip: 'View Sale Breakdown & Products',
                                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              await Printing.layoutPdf(
                                                onLayout: (format) => DesktopReceiptGenerator.generateThermal80(
                                                  store: const DesktopStoreInfo(storeName: 'FreshMart Store'),
                                                  invoice: inv,
                                                  items: sale.items,
                                                ),
                                                name: 'Receipt_${inv.invoiceNumber}',
                                              );
                                            },
                                            tooltip: 'Print Thermal Receipt',
                                            icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String method) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (method.toLowerCase()) {
      case 'cash':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        label = 'Cash';
        icon = Icons.payments_outlined;
        break;
      case 'upi_qr':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF6B21A8);
        label = 'UPI QR';
        icon = Icons.qr_code_2_rounded;
        break;
      case 'card':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1E40AF);
        label = 'Card';
        icon = Icons.credit_card_outlined;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = method.toUpperCase();
        icon = Icons.payment_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isSynced = status.toLowerCase() == 'synced';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSynced ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSynced ? const Color(0xFF10B981) : const Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isSynced ? 'Synced' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSynced ? const Color(0xFF065F46) : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}

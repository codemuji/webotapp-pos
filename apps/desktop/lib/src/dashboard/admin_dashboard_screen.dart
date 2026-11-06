import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../sales/invoice_detail_dialog.dart';

/// Executive Store Admin Dashboard showing real-time revenue, order metrics,
/// payment method breakdown, cashier performance, and recent synced sales transactions.
class AdminDashboardScreen extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onNavigateToSales;

  const AdminDashboardScreen({
    super.key,
    required this.database,
    this.onNavigateToSales,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardMetrics? _metrics;
  List<InvoiceWithItems> _recentSales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final metrics = await widget.database.getDashboardMetrics();
    final recent = await widget.database.getRecentInvoicesWithItems(limit: 5);
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _recentSales = recent;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                              'Store Executive Dashboard',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Real-time revenue, orders, and payment method analytics',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _loadMetrics,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Metrics',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Top Metric Cards Row
                  if (_metrics != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            title: 'Total Revenue',
                            value: '₹${_metrics!.totalRevenue.toStringAsFixed(2)}',
                            icon: Icons.currency_rupee_rounded,
                            iconColor: const Color(0xFF10B981), // Emerald
                            accentBg: const Color(0xFFECFDF5),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _MetricCard(
                            title: 'Orders Completed',
                            value: '${_metrics!.orderCount}',
                            icon: Icons.receipt_long_rounded,
                            iconColor: const Color(0xFF3B82F6), // Blue
                            accentBg: const Color(0xFFEFF6FF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _MetricCard(
                            title: 'Average Bill Value',
                            value: '₹${_metrics!.averageOrderValue.toStringAsFixed(2)}',
                            icon: Icons.analytics_rounded,
                            iconColor: const Color(0xFF8B5CF6), // Purple
                            accentBg: const Color(0xFFF5F3FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Analytics Breakdown Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Breakdown Card
                        Expanded(
                          flex: 1,
                          child: _CardContainer(
                            title: 'Payment Methods Breakdown',
                            icon: Icons.pie_chart_outline_rounded,
                            child: _metrics!.paymentBreakdown.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text(
                                        'No transactions recorded',
                                        style: TextStyle(color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: _metrics!.paymentBreakdown.entries.map((entry) {
                                      final label = _formatPaymentMethod(entry.key);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: _colorForPaymentMethod(entry.key),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  label,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '₹${entry.value.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Cashier Performance Card
                        Expanded(
                          flex: 1,
                          child: _CardContainer(
                            title: 'Cashier Sales Breakdown',
                            icon: Icons.badge_outlined,
                            child: _metrics!.cashierBreakdown.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text(
                                        'No sales recorded',
                                        style: TextStyle(color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: _metrics!.cashierBreakdown.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 18,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '₹${entry.value.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Synced Sales Section
                    _CardContainer(
                      title: 'Recent Synced Sales & Transactions',
                      icon: Icons.receipt_long_rounded,
                      action: widget.onNavigateToSales != null
                          ? TextButton.icon(
                              onPressed: widget.onNavigateToSales,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: const Text('View All Sales'),
                            )
                          : null,
                      child: _recentSales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No sales synced from mobile terminals yet',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Terminal / Cashier', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Items', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                    DataColumn(label: Text('Discounts', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                    DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _recentSales.map((sale) {
                                    final inv = sale.invoice;
                                    final dateFormat = DateFormat('dd MMM, hh:mm a');
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            inv.invoiceNumber,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                          ),
                                        ),
                                        DataCell(Text(dateFormat.format(inv.createdAt), style: const TextStyle(fontSize: 12))),
                                        DataCell(Text('${inv.deviceId} (${inv.employeeId})', style: const TextStyle(fontSize: 12))),
                                        DataCell(Text('${sale.items.length}')),
                                        DataCell(
                                          inv.discount > 0
                                              ? Text(
                                                  '-₹${inv.discount.toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12),
                                                )
                                              : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                                        ),
                                        DataCell(
                                          Text(
                                            '₹${inv.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _colorForPaymentMethod(inv.paymentMethod).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _formatPaymentMethod(inv.paymentMethod),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _colorForPaymentMethod(inv.paymentMethod),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            onPressed: () => showInvoiceDetailDialog(
                                              context: context,
                                              invoiceWithItems: sale,
                                            ),
                                            tooltip: 'View Sale Breakdown & Products',
                                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'CASH';
      case 'upi_qr':
        return 'UPI QR';
      case 'card':
        return 'CARD';
      default:
        return method.toUpperCase();
    }
  }

  Color _colorForPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFF10B981);
      case 'upi_qr':
        return const Color(0xFF3B82F6);
      case 'card':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color accentBg;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  const _CardContainer({
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF475569)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

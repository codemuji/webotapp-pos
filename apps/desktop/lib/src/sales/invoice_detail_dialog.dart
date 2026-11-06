import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'desktop_receipt_generator.dart';

/// Opens a comprehensive, interactive modal displaying the full synced invoice details,
/// line items table with offers/discounts, and allows instant receipt printing.
Future<void> showInvoiceDetailDialog({
  required BuildContext context,
  required InvoiceWithItems invoiceWithItems,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _InvoiceDetailDialogContent(data: invoiceWithItems),
  );
}

class _InvoiceDetailDialogContent extends StatelessWidget {
  final InvoiceWithItems data;

  const _InvoiceDetailDialogContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final inv = data.invoice;
    final items = data.items;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Recorded on ${dateFormat.format(inv.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Metadata Row (Terminal, Cashier, Payment Method, Sync Status)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaChip(Icons.phone_android_rounded, 'Terminal', inv.deviceId),
                    _buildMetaChip(Icons.person_outline_rounded, 'Cashier', inv.employeeId),
                    _buildMetaChip(Icons.payment_rounded, 'Payment', inv.paymentMethod.toUpperCase()),
                    _buildSyncStatusBadge(inv.syncStatus),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Purchased Products & Offers Breakdown',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),

              // Line Items Data Table
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      dataRowColor: WidgetStateProperty.all(Colors.white),
                      columnSpacing: 18,
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 13),
                      dataTextStyle: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Item / Product')),
                        DataColumn(label: Text('Barcode / SKU')),
                        DataColumn(label: Text('Unit Price'), numeric: true),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Offer / Disc'), numeric: true),
                        DataColumn(label: Text('Tax (GST)'), numeric: true),
                        DataColumn(label: Text('Line Total'), numeric: true),
                      ],
                      rows: items.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                item.productName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataCell(
                              Text(
                                item.barcode ?? '-',
                                style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                            DataCell(Text('₹${item.unitPrice.toStringAsFixed(2)}')),
                            DataCell(
                              Text(
                                item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              item.discount > 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '-₹${item.discount.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    )
                                  : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
                            DataCell(
                              item.taxAmount > 0
                                  ? Text('₹${item.taxAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF475569)))
                                  : const Text('0%'),
                            ),
                            DataCell(
                              Text(
                                '₹${item.lineTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Financial Breakdown & Totals Box
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Subtotal', '₹${inv.subtotal.toStringAsFixed(2)}'),
                      if (inv.discount > 0)
                        _buildSummaryRow('Total Offer / Discount', '-₹${inv.discount.toStringAsFixed(2)}', isDiscount: true),
                      if (inv.taxAmount > 0)
                        _buildSummaryRow('Taxes (GST)', '₹${inv.taxAmount.toStringAsFixed(2)}'),
                      const Divider(thickness: 1, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Grand Total',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${inv.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Printing.layoutPdf(
                        onLayout: (format) => DesktopReceiptGenerator.generateThermal80(
                          store: const DesktopStoreInfo(storeName: 'FreshMart Store'),
                          invoice: inv,
                          items: items,
                        ),
                        name: 'Receipt_${inv.invoiceNumber}',
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print Thermal Receipt (80mm)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatusBadge(String status) {
    final isSynced = status.toLowerCase() == 'synced';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSynced ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSynced ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isSynced ? const Color(0xFF10B981) : const Color(0xFFD97706),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Synced to Desktop' : 'Pending Sync',
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

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFFD97706) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

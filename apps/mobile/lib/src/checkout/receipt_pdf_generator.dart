import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Supported receipt layouts.
enum ReceiptFormat {
  thermal58,
  thermal80,
  a4,
}

/// Metadata describing the grocery store.
class StoreInfo {
  final String storeName;
  final String address;
  final String phone;
  final String? gstin;

  const StoreInfo({
    required this.storeName,
    required this.address,
    required this.phone,
    this.gstin,
  });
}

/// A line item on the printed receipt.
class ReceiptItem {
  final String name;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal total;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

/// Complete receipt snapshot for PDF rendering.
class ReceiptData {
  final String invoiceNumber;
  final String cashierName;
  final DateTime createdAt;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final Decimal subtotal;
  final Decimal discount;
  final Decimal taxAmount;
  final Decimal totalAmount;
  final Decimal? tenderedAmount;
  final Decimal? changeDue;

  const ReceiptData({
    required this.invoiceNumber,
    required this.cashierName,
    required this.createdAt,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.totalAmount,
    this.tenderedAmount,
    this.changeDue,
  });
}

/// High-performance deterministic receipt PDF builder supporting thermal 58mm, 80mm, and A4 formats.
class ReceiptPdfGenerator {
  static Future<Uint8List> generate({
    required StoreInfo store,
    required ReceiptData receipt,
    ReceiptFormat format = ReceiptFormat.thermal80,
  }) async {
    final pdf = pw.Document();

    final PdfPageFormat pageFormat;
    final double margin;

    switch (format) {
      case ReceiptFormat.thermal58:
        pageFormat = const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        );
        margin = 3 * PdfPageFormat.mm;
        break;
      case ReceiptFormat.thermal80:
        pageFormat = const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        );
        margin = 4 * PdfPageFormat.mm;
        break;
      case ReceiptFormat.a4:
        pageFormat = PdfPageFormat.a4;
        margin = 15 * PdfPageFormat.mm;
        break;
    }

    final isThermal = format == ReceiptFormat.thermal58 || format == ReceiptFormat.thermal80;
    final fontSizeMultiplier = format == ReceiptFormat.thermal58 ? 0.8 : 1.0;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(margin),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Store Header
                pw.Text(
                  store.storeName,
                  style: pw.TextStyle(
                    fontSize: 14 * fontSizeMultiplier,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  store.address,
                  style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Phone: ${store.phone}',
                  style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier),
                  textAlign: pw.TextAlign.center,
                ),
                if (store.gstin != null)
                  pw.Text(
                    'GSTIN: ${store.gstin}',
                    style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier),
                    textAlign: pw.TextAlign.center,
                  ),

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),

                // Meta Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Inv: ${receipt.invoiceNumber}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    pw.Text(dateFormat.format(receipt.createdAt), style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cashier: ${receipt.cashierName}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    pw.Text('Mode: ${receipt.paymentMethod}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold)),
                  ],
                ),

                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.5),

                // Line Items Table Header
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('Item', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Qty x Rate', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Amount', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5),

                // Line Items
                ...receipt.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Text(item.name, style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('${item.quantity} x Rs. ${item.unitPrice}', style: pw.TextStyle(fontSize: 7 * fontSizeMultiplier), textAlign: pw.TextAlign.center),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text('Rs. ${item.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }),

                pw.Divider(thickness: 0.5),

                // Financial Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    pw.Text('Rs. ${receipt.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                  ],
                ),
                if (receipt.discount > Decimal.zero)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Discount:', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                      pw.Text('-Rs. ${receipt.discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    ],
                  ),
                if (receipt.taxAmount > Decimal.zero)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Taxes (GST):', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                      pw.Text('Rs. ${receipt.taxAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    ],
                  ),

                pw.Divider(thickness: 1),

                // Total Amount
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL PAYABLE:',
                      style: pw.TextStyle(fontSize: 10 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Rs. ${receipt.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 11 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),

                if (receipt.tenderedAmount != null && receipt.tenderedAmount! > Decimal.zero) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cash Tendered:', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                      pw.Text('Rs. ${receipt.tenderedAmount!.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier)),
                    ],
                  ),
                  if (receipt.changeDue != null)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Change Due:', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Rs. ${receipt.changeDue!.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                ],

                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.5),

                // Footer Message
                pw.SizedBox(height: 4),
                pw.Text(
                  'Thank you for shopping with us!',
                  style: pw.TextStyle(fontSize: 8 * fontSizeMultiplier, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Please visit again',
                  style: pw.TextStyle(fontSize: 7 * fontSizeMultiplier),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}

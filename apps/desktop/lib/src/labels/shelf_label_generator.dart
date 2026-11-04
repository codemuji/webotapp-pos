import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Metadata for store branding on shelf tags.
class LabelStoreInfo {
  final String storeName;

  const LabelStoreInfo({required this.storeName});
}

/// Data payload required to render a product shelf label.
class ProductLabelData {
  final String name;
  final String? barcode;
  final String? sku;
  final double sellingPrice;
  final String unit;

  const ProductLabelData({
    required this.name,
    this.barcode,
    this.sku,
    required this.sellingPrice,
    this.unit = 'pcs',
  });
}

/// Generates printable thermal shelf barcode and QR labels (standard 50mm x 30mm format).
class ShelfLabelGenerator {
  static const PdfPageFormat labelFormat = PdfPageFormat(
    50 * PdfPageFormat.mm,
    30 * PdfPageFormat.mm,
    marginAll: 2 * PdfPageFormat.mm,
  );

  /// Generates a single thermal shelf label PDF.
  static Future<Uint8List> generateLabel({
    required LabelStoreInfo store,
    required ProductLabelData product,
  }) {
    return generateBatch(
      store: store,
      products: [product],
    );
  }

  /// Generates a multi-page batch of thermal shelf labels PDF.
  static Future<Uint8List> generateBatch({
    required LabelStoreInfo store,
    required List<ProductLabelData> products,
  }) async {
    final pdf = pw.Document();

    for (final product in products) {
      pdf.addPage(
        pw.Page(
          pageFormat: labelFormat,
          build: (context) {
            final barcodeData = product.barcode != null && product.barcode!.isNotEmpty
                ? product.barcode!
                : (product.sku ?? '000000');

            return pw.Container(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Store Header
                  pw.Text(
                    store.storeName,
                    style: pw.TextStyle(
                      fontSize: 6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),

                  // Product Name
                  pw.Text(
                    product.name,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    maxLines: 1,
                    textAlign: pw.TextAlign.center,
                  ),

                  // Price Tag
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Rs. ${product.sellingPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        ' / ${product.unit}',
                        style: const pw.TextStyle(
                          fontSize: 6,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),

                  // Barcode Graphic
                  pw.SizedBox(
                    height: 16,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      drawText: false,
                    ),
                  ),

                  // Barcode text caption
                  pw.Text(
                    barcodeData,
                    style: const pw.TextStyle(fontSize: 5),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }
}

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/labels/shelf_label_generator.dart';

void main() {
  group('ShelfLabelGenerator - Slice 4: Thermal Barcode & QR Shelf Label Generator', () {
    const store = LabelStoreInfo(
      storeName: 'FRESH MART GROCERY',
    );

    const product = ProductLabelData(
      name: 'Amul Butter 100g',
      barcode: '8901262010111',
      sku: 'DRY-BTR-100',
      sellingPrice: 58.0,
      unit: 'pcs',
    );

    test('generates valid thermal shelf label PDF with barcode', () async {
      final pdfBytes = await ShelfLabelGenerator.generateLabel(
        store: store,
        product: product,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(500));
      // Magic header %PDF-
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('generates batch shelf labels PDF for multiple products', () async {
      final products = [
        product,
        const ProductLabelData(
          name: 'Basmati Rice 5kg',
          barcode: '8901234000001',
          sku: 'GR-RIC-05',
          sellingPrice: 450.0,
          unit: 'bag',
        ),
      ];

      final pdfBytes = await ShelfLabelGenerator.generateBatch(
        store: store,
        products: products,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });
  });
}

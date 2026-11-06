import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/catalog/barcode_generator.dart';

void main() {
  group('BarcodeGenerator - GS1 EAN-13 & Store SKU Generation', () {
    test('calculates correct GS1 EAN-13 checksum for known test barcodes', () {
      // 890103038374 -> check digit 8
      expect(BarcodeGenerator.calculateEan13CheckDigit('890103038374'), '8');
      expect(BarcodeGenerator.isValidEan13('8901030383748'), isTrue);

      // 400638133393 -> check digit 1 (Stabilo Boss highlighter)
      expect(BarcodeGenerator.calculateEan13CheckDigit('400638133393'), '1');
      expect(BarcodeGenerator.isValidEan13('4006381333931'), isTrue);
    });

    test('generateEan13 generates a valid 13-digit EAN barcode with check digit', () {
      final barcode = BarcodeGenerator.generateEan13(prefix: '20');
      expect(barcode.length, 13);
      expect(barcode.startsWith('20'), isTrue);
      expect(BarcodeGenerator.isValidEan13(barcode), isTrue);
    });

    test('generateStoreSku produces formatted SKU string', () {
      final sku = BarcodeGenerator.generateStoreSku(prefix: 'GROC');
      expect(sku.startsWith('GROC-'), isTrue);
      expect(sku.length, greaterThanOrEqualTo(8));
    });
  });
}


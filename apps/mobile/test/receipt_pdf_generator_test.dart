import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/checkout/receipt_pdf_generator.dart';

void main() {
  group('ReceiptPdfGenerator - Slice 3: Thermal 58mm/80mm and A4 PDF Rendering', () {
    late StoreInfo store;
    late ReceiptData receipt;

    setUp(() {
      store = const StoreInfo(
        storeName: 'FRESH MART GROCERY',
        address: 'Shop 12, Main Market, Indiranagar, Bengaluru',
        phone: '+91 98765 43210',
        gstin: '29ABCDE1234F1Z5',
      );

      receipt = ReceiptData(
        invoiceNumber: 'INV-20261103-1001',
        cashierName: 'Aarav Sharma',
        createdAt: DateTime(2026, 11, 3, 17, 45),
        paymentMethod: 'CASH',
        items: [
          ReceiptItem(
            name: 'Aashirvaad Atta 5kg',
            quantity: Decimal.parse('1'),
            unitPrice: Decimal.parse('245.00'),
            total: Decimal.parse('245.00'),
          ),
          ReceiptItem(
            name: 'Amul Butter 100g',
            quantity: Decimal.parse('2'),
            unitPrice: Decimal.parse('58.00'),
            total: Decimal.parse('116.00'),
          ),
        ],
        subtotal: Decimal.parse('361.00'),
        discount: Decimal.zero,
        taxAmount: Decimal.parse('18.05'),
        totalAmount: Decimal.parse('361.00'),
        tenderedAmount: Decimal.parse('500.00'),
        changeDue: Decimal.parse('139.00'),
      );
    });

    test('generates non-empty valid PDF bytes for thermal 80mm format', () async {
      final pdfBytes = await ReceiptPdfGenerator.generate(
        store: store,
        receipt: receipt,
        format: ReceiptFormat.thermal80,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF magic header: %PDF-
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('generates valid PDF bytes for thermal 58mm format', () async {
      final pdfBytes = await ReceiptPdfGenerator.generate(
        store: store,
        receipt: receipt,
        format: ReceiptFormat.thermal58,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('generates valid PDF bytes for standard A4 format', () async {
      final pdfBytes = await ReceiptPdfGenerator.generate(
        store: store,
        receipt: receipt,
        format: ReceiptFormat.a4,
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });
  });
}


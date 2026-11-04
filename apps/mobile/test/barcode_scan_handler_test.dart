import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';
import 'package:mobile/src/scanner/barcode_scan_handler.dart';

void main() {
  late AppDatabase db;
  late CartNotifier cartNotifier;
  late BarcodeScanHandler handler;
  var hapticTriggered = false;

  setUp(() async {
    db = AppDatabase.inMemory();
    cartNotifier = CartNotifier();
    hapticTriggered = false;

    handler = BarcodeScanHandler(
      database: db,
      cartNotifier: cartNotifier,
      onHapticFeedback: () => hapticTriggered = true,
      debounceDuration: const Duration(milliseconds: 300),
    );

    // Seed test product
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'prod-cornflakes',
            name: 'Kelloggs Corn Flakes 500g',
            barcode: const Value('8901234567890'),
            sellingPrice: 185.0,
            unit: const Value('box'),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('BarcodeScanHandler - Slice 1: Real-time Scan Processing', () {
    test('successfully scans recognized barcode, adds to cart, and triggers haptic pulse', () async {
      final result = await handler.onBarcodeScanned('8901234567890');

      expect(result.status, equals(ScanStatus.found));
      expect(result.product?.name, equals('Kelloggs Corn Flakes 500g'));
      expect(hapticTriggered, isTrue);

      // Verify cart state
      expect(cartNotifier.state.items.length, equals(1));
      expect(cartNotifier.state.items.first.productId, equals('prod-cornflakes'));
      expect(cartNotifier.state.items.first.quantity, equals(Decimal.one));
      expect(cartNotifier.state.totalAmount, equals(Decimal.parse('185.0')));
    });

    test('returns notFound when barcode does not exist in local database', () async {
      final result = await handler.onBarcodeScanned('9999999999999');

      expect(result.status, equals(ScanStatus.notFound));
      expect(result.rawBarcode, equals('9999999999999'));
      expect(hapticTriggered, isFalse);
      expect(cartNotifier.state.items, isEmpty);
    });

    test('debounces identical barcode scanned within 300ms video frames', () async {
      // First scan
      final res1 = await handler.onBarcodeScanned('8901234567890');
      expect(res1.status, equals(ScanStatus.found));
      expect(cartNotifier.state.items.first.quantity, equals(Decimal.one));

      // Rapid duplicate frame (50ms later)
      final res2 = await handler.onBarcodeScanned('8901234567890');
      expect(res2.status, equals(ScanStatus.debounced));
      expect(cartNotifier.state.items.first.quantity, equals(Decimal.one)); // Not incremented

      // Wait past debounce duration (350ms)
      await Future.delayed(const Duration(milliseconds: 350));

      // Legitimate second scan
      final res3 = await handler.onBarcodeScanned('8901234567890');
      expect(res3.status, equals(ScanStatus.found));
      expect(cartNotifier.state.items.first.quantity, equals(Decimal.parse('2'))); // Incremented
    });
  });
}


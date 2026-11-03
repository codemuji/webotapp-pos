import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';
import 'package:mobile/src/scanner/barcode_scan_handler.dart';
import 'package:mobile/src/scanner/barcode_scanner_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p-butter',
            name: 'Amul Butter 100g',
            barcode: const Value('8901262010111'),
            sellingPrice: 58.0,
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('BarcodeScannerScreen - Slice 3: Camera Scanning & Cart Connection', () {
    testWidgets('renders scanner HUD, reticle, torch toggle, and cart badge', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BarcodeScannerScreen(
              database: db,
              isSimulationMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Point camera at barcode or QR code'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('0 items in cart'), findsOneWidget);
    });

    testWidgets('processes scanned barcode, adds to cart and updates cart badge', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BarcodeScannerScreen(
              database: db,
              isSimulationMode: true,
            ),
          ),
        ),
      );

      // Trigger barcode scan simulation
      final scannerState = tester.state<BarcodeScannerScreenState>(find.byType(BarcodeScannerScreen));
      await scannerState.handleBarcode('8901262010111');
      await tester.pump();

      // Verify cart badge updated
      expect(find.text('1 items • ₹58.00'), findsOneWidget);
      final cart = container.read(cartProvider);
      expect(cart.items.length, equals(1));
      expect(cart.items.first.productName, equals('Amul Butter 100g'));
    });

    testWidgets('displays not found snackbar when scanning unknown barcode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BarcodeScannerScreen(
              database: db,
              isSimulationMode: true,
            ),
          ),
        ),
      );

      final scannerState = tester.state<BarcodeScannerScreenState>(find.byType(BarcodeScannerScreen));
      await scannerState.handleBarcode('0000000000000');
      await tester.pump();

      expect(find.text('Barcode 0000000000000 not found in catalog'), findsOneWidget);
      expect(container.read(cartProvider).items, isEmpty);
    });
  });
}

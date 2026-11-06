import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/catalog/low_stock_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-bakery',
        name: 'Bakery & Bread',
      ),
    );

    // Out of stock product
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-bread-01',
        name: 'Whole Wheat Bread',
        barcode: const Value('8901234000101'),
        sku: const Value('BK-BRD-01'),
        categoryId: const Value('cat-bakery'),
        sellingPrice: 40.0,
        purchasePrice: const Value(30.0),
        stockQuantity: const Value(0.0),
        minStockAlert: const Value(10.0),
        updatedAt: DateTime.now(),
      ),
    );

    // Critical product (2 <= 5)
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-buns-01',
        name: 'Burger Buns 4pk',
        barcode: const Value('8901234000102'),
        sku: const Value('BK-BUN-04'),
        categoryId: const Value('cat-bakery'),
        sellingPrice: 35.0,
        purchasePrice: const Value(25.0),
        stockQuantity: const Value(2.0),
        minStockAlert: const Value(10.0),
        updatedAt: DateTime.now(),
      ),
    );

    // Healthy product (20 > 5)
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-flour-01',
        name: 'All Purpose Flour 1kg',
        barcode: const Value('8901234000103'),
        sku: const Value('BK-FLR-01'),
        categoryId: const Value('cat-bakery'),
        sellingPrice: 50.0,
        purchasePrice: const Value(38.0),
        stockQuantity: const Value(20.0),
        minStockAlert: const Value(5.0),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('LowStockScreen - Inventory Replenishment & Safety Thresholds', () {
    testWidgets('renders KPI cards, low stock items, and health badges', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LowStockScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Low Stock & Replenishment Console'), findsOneWidget);
      expect(find.text('Whole Wheat Bread'), findsOneWidget);
      expect(find.text('Burger Buns 4pk'), findsOneWidget);
      expect(find.text('All Purpose Flour 1kg'), findsNothing); // Healthy item not in low stock list

      expect(find.text('OUT OF STOCK'), findsOneWidget);
      expect(find.text('CRITICAL DEFICIT'), findsOneWidget);
    });

    testWidgets('quick restock dialog adds stock and records inventory movement', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LowStockScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap restock on the first item (Whole Wheat Bread)
      final restockButtons = find.text('Restock');
      expect(restockButtons, findsWidgets);

      await tester.tap(restockButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Quick Restock Inventory'), findsOneWidget);
      expect(find.text('Confirm Restock'), findsOneWidget);

      await tester.tap(find.text('Confirm Restock'));
      await tester.pumpAndSettle();

      // Verify product stock in database is now positive
      final updated = await (db.select(db.products)..where((t) => t.id.equals('prod-bread-01'))).getSingle();
      expect(updated.stockQuantity, greaterThan(0.0));

      final movements = await db.select(db.inventoryMovements).get();
      expect(movements.any((m) => m.productId == 'prod-bread-01' && m.reason == 'restock'), isTrue);
    });
  });
}


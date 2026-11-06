import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/catalog/product_catalog_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    // Seed Categories
    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-oil',
        name: 'Cooking Oils',
        defaultTaxRate: const Value(5.0),
        defaultHsnCode: const Value('1507'),
      ),
    );
    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-snacks',
        name: 'Snacks & Biscuits',
        defaultTaxRate: const Value(12.0),
        defaultHsnCode: const Value('1905'),
      ),
    );

    // Seed Parent Product and Variants
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-oil-parent',
        name: 'Fortune Sunlite Oil',
        variantName: const Value('1 Litre Pouch'),
        barcode: const Value('8901234001001'),
        sku: const Value('OIL-FS-1L'),
        categoryId: const Value('cat-oil'),
        sellingPrice: 135.0,
        purchasePrice: const Value(110.0),
        stockQuantity: const Value(40.0),
        unit: const Value('l'),
        taxRate: const Value(5.0),
        minStockAlert: const Value(10.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-oil-5l',
        name: 'Fortune Sunlite Oil',
        variantName: const Value('5 Litre Jar'),
        parentProductId: const Value('prod-oil-parent'),
        barcode: const Value('8901234001002'),
        secondaryBarcode: const Value('8901234001009'), // Case box barcode
        sku: const Value('OIL-FS-5L'),
        categoryId: const Value('cat-oil'),
        sellingPrice: 650.0,
        purchasePrice: const Value(540.0),
        stockQuantity: const Value(3.0), // Low stock
        unit: const Value('l'),
        taxRate: const Value(5.0),
        minStockAlert: const Value(5.0),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductCatalogScreen - Grocery Pack-Size Variants & Low Stock Features', () {
    testWidgets('renders linked variants with pack size badge and low stock indicator', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProductCatalogScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check variant badges
      expect(find.text('1 Litre Pouch'), findsOneWidget);
      expect(find.text('5 Litre Jar'), findsOneWidget);
      expect(find.text('↳ Linked pack-size variant'), findsOneWidget);

      // Check secondary/alternate barcode rendered
      expect(find.text('Alt: 8901234001009'), findsOneWidget);

      // Check Low Stock indicator for 5L jar (stock 3 <= minStock 5)
      expect(find.text('Low Stock'), findsOneWidget);

      // Check Category filter chip counts
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Cooking Oils (2)'), findsOneWidget);
      expect(find.text('Snacks & Biscuits (0)'), findsOneWidget);
    });

    testWidgets('filters list by tapping category chips', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProductCatalogScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Snacks & Biscuits (0)' chip
      await tester.tap(find.text('Snacks & Biscuits (0)'));
      await tester.pumpAndSettle();

      // Oil products should be filtered out
      expect(find.text('1 Litre Pouch'), findsNothing);
      expect(find.text('5 Litre Jar'), findsNothing);

      // Tap 'All (2)' to reset
      await tester.tap(find.text('All (2)'));
      await tester.pumpAndSettle();

      expect(find.text('1 Litre Pouch'), findsOneWidget);
    });

    testWidgets('commits quick restock adjustment and updates inventory', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProductCatalogScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap restock icon on the first product
      final restockIcons = find.byIcon(Icons.add_shopping_cart_rounded);
      expect(restockIcons, findsNWidgets(2));
      await tester.tap(restockIcons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Adjust Stock:'), findsOneWidget);

      // Submit Restock (default adds 10)
      await tester.tap(find.text('Commit Adjustment'));
      await tester.pumpAndSettle();

      // Verify stock in database increased from 40 to 50
      final product = await (db.select(db.products)..where((p) => p.id.equals('prod-oil-parent'))).getSingle();
      expect(product.stockQuantity, equals(50.0));
    });
  });
}


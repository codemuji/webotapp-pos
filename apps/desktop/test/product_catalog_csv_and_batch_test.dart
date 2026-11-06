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

    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-staples',
        name: 'Staples',
        defaultTaxRate: const Value(5.0),
        defaultHsnCode: const Value('1001'),
      ),
    );

    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-item-1',
        name: 'Sugar M30',
        variantName: const Value('1kg Pack'),
        barcode: const Value('8901234000111'),
        sku: const Value('SKU-SUG-1'),
        categoryId: const Value('cat-staples'),
        sellingPrice: 48.0,
        purchasePrice: const Value(40.0),
        stockQuantity: const Value(2.0), // Low stock
        minStockAlert: const Value(5.0),
        unit: const Value('kg'),
        updatedAt: DateTime.now(),
      ),
    );

    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-item-2',
        name: 'Wheat Flour',
        variantName: const Value('10kg Bag'),
        barcode: const Value('8901234000222'),
        sku: const Value('SKU-WHT-10'),
        categoryId: const Value('cat-staples'),
        sellingPrice: 420.0,
        purchasePrice: const Value(360.0),
        stockQuantity: const Value(25.0), // Ample stock
        minStockAlert: const Value(5.0),
        unit: const Value('kg'),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductCatalogScreen - Bulk CSV & Batch Operations', () {
    testWidgets('renders CSV import and export buttons in header', (tester) async {
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

      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Import CSV'), findsOneWidget);
      expect(find.text('⚠️ Low Stock (1)'), findsOneWidget);
    });

    testWidgets('filters exclusively by low stock items when Low Stock chip is selected', (tester) async {
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

      // Tap Low Stock filter chip
      await tester.tap(find.text('⚠️ Low Stock (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Sugar M30'), findsOneWidget);
      expect(find.text('Wheat Flour'), findsNothing);
    });

    testWidgets('opens CSV import dialog, parses pasted text, and commits import', (tester) async {
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

      // Tap Import CSV button
      await tester.tap(find.text('Import CSV'));
      await tester.pumpAndSettle();

      expect(find.text('Bulk Catalog CSV Import'), findsOneWidget);
      expect(find.text('Download Sample CSV'), findsOneWidget);

      // Paste CSV content
      const sampleCsv = '''Name,Variant,Barcode,SecondaryBarcode,SKU,Category,SellingPrice,CostPrice,StockQuantity,Unit,TaxRate,HSNCode,MinStockAlert
Basmati Daily,1kg,8901234999001,,SKU-BAS-1,Rice & Grains,95.00,78.00,40,kg,5.0,1006,10
''';
      await tester.enterText(find.byType(TextField).last, sampleCsv);
      await tester.pumpAndSettle();

      expect(find.textContaining('Parsed 1 rows: 1 valid'), findsOneWidget);
      expect(find.text('Commit Import (1 Items)'), findsOneWidget);

      // Tap Commit Import
      await tester.tap(find.text('Commit Import (1 Items)'));
      await tester.pumpAndSettle();

      // Verify product rendered in list and in DB
      expect(find.text('Basmati Daily'), findsOneWidget);
      final imported = await db.getProductByBarcode('8901234999001');
      expect(imported, isNotNull);
      expect(imported!.name, equals('Basmati Daily'));
      expect(imported.sellingPrice, equals(95.0));
    });

    testWidgets('selects items via checkboxes and displays batch operations toolbar', (tester) async {
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

      // Initially no batch toolbar
      expect(find.textContaining('selected for batch operations'), findsNothing);

      // Tap the first checkbox (select all in table header)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3)); // 1 header + 2 rows

      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      expect(find.text('2 products selected for batch operations'), findsOneWidget);
      expect(find.text('Print 2 Shelf Labels'), findsOneWidget);

      // Clear selection
      await tester.tap(find.text('Clear Selection'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected for batch operations'), findsNothing);
    });
  });
}


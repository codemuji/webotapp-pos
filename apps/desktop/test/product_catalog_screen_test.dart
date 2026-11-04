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

    // Insert initial category and product
    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-grains',
        name: 'Grains & Pulses',
      ),
    );

    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-rice-01',
        name: 'Basmati Rice 5kg',
        barcode: const Value('8901234000001'),
        sku: const Value('GR-RIC-05'),
        categoryId: const Value('cat-grains'),
        sellingPrice: 450.0,
        purchasePrice: const Value(380.0),
        stockQuantity: const Value(15.0),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductCatalogScreen - Slice 3: Catalog & Category Management Table', () {
    testWidgets('renders products table, search input, and add buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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

      expect(find.text('Product & Category Catalog'), findsOneWidget);
      expect(find.text('Basmati Rice 5kg'), findsOneWidget);
      expect(find.text('8901234000001'), findsOneWidget);
      expect(find.text('₹450.00'), findsOneWidget);
      expect(find.text('₹380.00'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);
    });

    testWidgets('creates a new product via Add Product dialog and updates list', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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

      // Open Add Product dialog
      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();

      expect(find.text('New Product Entry'), findsOneWidget);

      // Fill in details
      await tester.enterText(find.byKey(const Key('input_product_name')), 'Toor Dal 1kg');
      await tester.enterText(find.byKey(const Key('input_product_barcode')), '8901234000002');
      await tester.enterText(find.byKey(const Key('input_product_selling_price')), '140.00');
      await tester.enterText(find.byKey(const Key('input_product_purchase_price')), '115.00');
      await tester.enterText(find.byKey(const Key('input_product_stock')), '30');

      // Submit
      await tester.tap(find.text('Save Product'));
      await tester.pumpAndSettle();

      // Verify product rendered in list
      expect(find.text('Toor Dal 1kg'), findsOneWidget);
      expect(find.text('8901234000002'), findsOneWidget);

      // Verify saved in SQLite database
      final saved = await db.getProductByBarcode('8901234000002');
      expect(saved, isNotNull);
      expect(saved!.sellingPrice, equals(140.0));
      expect(saved.purchasePrice, equals(115.0));
    });

    testWidgets('deactivates an active product and toggles status badge', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
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

      // Tap Deactivate switch / button
      final toggleFinder = find.byKey(const Key('toggle_active_prod-rice-01'));
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Inactive'), findsOneWidget);

      final product = await (db.select(db.products)..where((p) => p.id.equals('prod-rice-01'))).getSingle();
      expect(product.isActive, isFalse);
    });
  });
}

import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/cart/cart_state.dart';
import 'package:mobile/src/scanner/manual_search_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p-sugar',
            name: 'Organic White Sugar 1kg',
            barcode: const Value('8901112223334'),
            sku: const Value('SUGAR-1KG'),
            sellingPrice: 55.0,
            unit: const Value('kg'),
            updatedAt: DateTime.now(),
          ),
        );

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p-salt',
            name: 'Iodized Table Salt 1kg',
            barcode: const Value('8904445556667'),
            sku: const Value('SALT-1KG'),
            sellingPrice: 22.0,
            unit: const Value('kg'),
            updatedAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('ManualProductSearchSheet - Slice 2: Local Catalog Search Fallback', () {
    testWidgets('searches products by name and adds selected product to cart', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showManualProductSearchSheet(
                    context: context,
                    database: db,
                  ),
                  child: const Text('Open Search'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Search'));
      await tester.pumpAndSettle();

      expect(find.text('Search Product Catalog'), findsOneWidget);

      // Enter search query 'Sugar'
      await tester.enterText(find.byType(TextField), 'Sugar');
      await tester.pumpAndSettle();

      // Verify search results
      expect(find.text('Organic White Sugar 1kg'), findsOneWidget);
      expect(find.text('Iodized Table Salt 1kg'), findsNothing);

      // Tap on sugar product tile
      await tester.tap(find.text('Organic White Sugar 1kg'));
      await tester.pumpAndSettle();

      // Verify sheet closed and item added to cart
      expect(find.text('Search Product Catalog'), findsNothing);
      final cart = container.read(cartProvider);
      expect(cart.items.length, equals(1));
      expect(cart.items.first.productId, equals('p-sugar'));
      expect(cart.totalAmount, equals(Decimal.parse('55.0')));
    });
  });
}


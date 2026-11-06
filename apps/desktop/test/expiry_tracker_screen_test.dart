import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/catalog/expiry_tracker_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    await db.upsertCategory(
      CategoriesCompanion.insert(
        id: 'cat-dairy',
        name: 'Dairy & Milk',
      ),
    );

    final now = DateTime.now();

    // Expired product (expired 3 days ago)
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-milk-01',
        name: 'Fresh Cow Milk 500ml',
        barcode: const Value('8901234000201'),
        sku: const Value('DY-MLK-01'),
        categoryId: const Value('cat-dairy'),
        sellingPrice: 35.0,
        purchasePrice: const Value(28.0),
        stockQuantity: const Value(5.0),
        expiryDate: Value(now.subtract(const Duration(days: 3))),
        batchNumber: const Value('B-2026-NOV1'),
        updatedAt: now,
      ),
    );

    // Expiring soon (expires in 4 days)
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-curd-01',
        name: 'Organic Curd 400g',
        barcode: const Value('8901234000202'),
        sku: const Value('DY-CRD-01'),
        categoryId: const Value('cat-dairy'),
        sellingPrice: 45.0,
        purchasePrice: const Value(36.0),
        stockQuantity: const Value(12.0),
        expiryDate: Value(now.add(const Duration(days: 4))),
        batchNumber: const Value('B-2026-NOV4'),
        updatedAt: now,
      ),
    );

    // Long shelf-life (expires in 120 days)
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'prod-ghee-01',
        name: 'Pure Desi Ghee 1L',
        barcode: const Value('8901234000203'),
        sku: const Value('DY-GHE-01'),
        categoryId: const Value('cat-dairy'),
        sellingPrice: 650.0,
        purchasePrice: const Value(520.0),
        stockQuantity: const Value(10.0),
        expiryDate: Value(now.add(const Duration(days: 120))),
        batchNumber: const Value('B-2026-DEC1'),
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpiryTrackerScreen - Shelf Life & Perishable Inventory Management', () {
    testWidgets('renders KPI cards, expiring items, batch codes, and countdown badges', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExpiryTrackerScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Product Expiry & Shelf-Life Tracker'), findsOneWidget);
      expect(find.text('Fresh Cow Milk 500ml'), findsOneWidget);
      expect(find.text('Organic Curd 400g'), findsOneWidget);
      expect(find.text('Pure Desi Ghee 1L'), findsOneWidget);

      expect(find.text('Batch: B-2026-NOV1'), findsOneWidget);
      expect(find.text('EXPIRED (3d AGO)'), findsOneWidget);
      expect(find.text('EXPIRES IN 4 DAYS'), findsOneWidget);
    });

    testWidgets('applies clearance markdown discount to near-expiry item', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExpiryTrackerScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Markdown on the near-expiry item (Organic Curd)
      final markdownBtn = find.widgetWithText(OutlinedButton, 'Markdown');
      expect(markdownBtn, findsWidgets);

      await tester.tap(markdownBtn.first);
      await tester.pumpAndSettle();

      expect(find.text('Clearance Markdown Discount'), findsOneWidget);

      // Select -50% preset
      await tester.tap(find.text('-50%'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply Markdown Price'));
      await tester.pumpAndSettle();

      final curd = await (db.select(db.products)..where((t) => t.id.equals('prod-curd-01'))).getSingle();
      expect(curd.sellingPrice, lessThan(45.0));
    });

    testWidgets('executes write-off disposal on expired stock and logs waste movement', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExpiryTrackerScreen(database: db),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Write-Off on the expired item
      final writeOffBtn = find.text('Write-Off');
      expect(writeOffBtn, findsWidgets);

      await tester.tap(writeOffBtn.first);
      await tester.pumpAndSettle();

      expect(find.text('Write-Off Expired Stock'), findsOneWidget);
      await tester.tap(find.text('Confirm Write-Off'));
      await tester.pumpAndSettle();

      final milk = await (db.select(db.products)..where((t) => t.id.equals('prod-milk-01'))).getSingle();
      expect(milk.stockQuantity, equals(0.0));

      final movements = await db.select(db.inventoryMovements).get();
      expect(movements.any((m) => m.productId == 'prod-milk-01' && m.reason == 'expired_waste'), isTrue);
    });
  });
}


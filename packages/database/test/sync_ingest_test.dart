import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase - Slice 1: Idempotent Synced Invoice Ingestion & Inventory Delta', () {
    test('successfully ingests new invoice, records items, and applies inventory deltas', () async {
      // 1. Setup category and product
      await db.upsertCategory(
        CategoriesCompanion.insert(id: 'cat-1', name: 'Dairy'),
      );
      final now = DateTime.now();
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-milk',
          name: 'Fresh Whole Milk 1L',
          barcode: const Value('890103000001'),
          categoryId: const Value('cat-1'),
          sellingPrice: 65.0,
          purchasePrice: const Value(50.0),
          stockQuantity: const Value(100.0),
          unit: const Value('pkt'),
          updatedAt: now,
        ),
      );

      final invoice = InvoicesCompanion.insert(
        id: 'inv-mobile-100',
        invoiceNumber: 'INV-20261104-001',
        deviceId: 'term-01',
        employeeId: 'emp-1',
        subtotal: 130.0,
        totalAmount: 130.0,
        paymentMethod: 'cash',
        createdAt: now,
        syncStatus: const Value('synced'),
      );

      final items = [
        InvoiceItemsCompanion.insert(
          id: 'item-100-1',
          invoiceId: 'inv-mobile-100',
          productId: const Value('prod-milk'),
          productName: 'Fresh Whole Milk 1L',
          barcode: const Value('890103000001'),
          quantity: 2.0,
          unitPrice: 65.0,
          lineTotal: 130.0,
        ),
      ];

      // Act
      final result = await db.ingestSyncedInvoice(
        invoice: invoice,
        items: items,
      );

      // Assert
      expect(result.isDuplicate, isFalse);
      expect(result.invoiceId, equals('inv-mobile-100'));

      // Check invoice persisted
      final storedInvoice = await (db.select(db.invoices)..where((tbl) => tbl.id.equals('inv-mobile-100'))).getSingle();
      expect(storedInvoice.totalAmount, equals(130.0));

      // Check items persisted
      final storedItems = await db.getItemsForInvoice('inv-mobile-100');
      expect(storedItems.length, equals(1));
      expect(storedItems.first.quantity, equals(2.0));

      // Check stock decremented from 100.0 to 98.0
      final updatedProduct = await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-milk'))).getSingle();
      expect(updatedProduct.stockQuantity, equals(98.0));

      // Check delta inventory audit log
      final movements = await db.getInventoryHistoryForProduct('prod-milk');
      expect(movements.length, equals(1));
      expect(movements.first.deltaQuantity, equals(-2.0));
      expect(movements.first.reason, equals('synced_sale'));
      expect(movements.first.referenceId, equals('inv-mobile-100'));
    });

    test('idempotency guard: duplicate invoice ingestion returns isDuplicate true without double-decrementing stock', () async {
      await db.upsertCategory(
        CategoriesCompanion.insert(id: 'cat-1', name: 'Dairy'),
      );
      final now = DateTime.now();
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-milk',
          name: 'Fresh Whole Milk 1L',
          barcode: const Value('890103000001'),
          categoryId: const Value('cat-1'),
          sellingPrice: 65.0,
          purchasePrice: const Value(50.0),
          stockQuantity: const Value(50.0),
          unit: const Value('pkt'),
          updatedAt: now,
        ),
      );

      final invoice = InvoicesCompanion.insert(
        id: 'inv-mobile-dup',
        invoiceNumber: 'INV-20261104-DUP',
        deviceId: 'term-01',
        employeeId: 'emp-1',
        subtotal: 65.0,
        totalAmount: 65.0,
        paymentMethod: 'cash',
        createdAt: now,
      );

      final items = [
        InvoiceItemsCompanion.insert(
          id: 'item-dup-1',
          invoiceId: 'inv-mobile-dup',
          productId: const Value('prod-milk'),
          productName: 'Fresh Whole Milk 1L',
          quantity: 1.0,
          unitPrice: 65.0,
          lineTotal: 65.0,
        ),
      ];

      // First ingestion
      final res1 = await db.ingestSyncedInvoice(invoice: invoice, items: items);
      expect(res1.isDuplicate, isFalse);

      final stockAfterFirst = (await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-milk'))).getSingle()).stockQuantity;
      expect(stockAfterFirst, equals(49.0));

      // Second ingestion (retry/duplicate)
      final res2 = await db.ingestSyncedInvoice(invoice: invoice, items: items);
      expect(res2.isDuplicate, isTrue);
      expect(res2.invoiceId, equals('inv-mobile-dup'));

      // Verify stock was NOT decremented again!
      final stockAfterSecond = (await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-milk'))).getSingle()).stockQuantity;
      expect(stockAfterSecond, equals(49.0));

      // Verify only 1 movement exists
      final movements = await db.getInventoryHistoryForProduct('prod-milk');
      expect(movements.length, equals(1));
    });
  });
}

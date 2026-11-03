import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase - Slice 1: Products & Categories Schema', () {
    test('inserts and retrieves categories and products by barcode', () async {
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat-1',
              name: 'Groceries',
            ),
          );

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-1',
              name: 'Basmati Rice 1kg',
              barcode: const Value('8901234567890'),
              sellingPrice: 120.0,
              purchasePrice: const Value(95.0),
              categoryId: const Value('cat-1'),
              unit: const Value('kg'),
              updatedAt: DateTime.now(),
            ),
          );

      final product = await db.getProductByBarcode('8901234567890');
      expect(product, isNotNull);
      expect(product!.name, equals('Basmati Rice 1kg'));
      expect(product.sellingPrice, equals(120.0));
      expect(product.categoryId, equals('cat-1'));
    });

    test('returns null when product barcode does not exist', () async {
      final product = await db.getProductByBarcode('9999999999999');
      expect(product, isNull);
    });

    test('filters active vs inactive products', () async {
      final now = DateTime.now();
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-active',
              name: 'Milk 500ml',
              sellingPrice: 30.0,
              isActive: const Value(true),
              updatedAt: now,
            ),
          );

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-inactive',
              name: 'Seasonal Mangoes',
              sellingPrice: 80.0,
              isActive: const Value(false),
              updatedAt: now,
            ),
          );

      final activeProducts = await db.getActiveProducts();
      expect(activeProducts.length, equals(1));
      expect(activeProducts.first.id, equals('prod-active'));
    });
  });

  group('AppDatabase - Slice 2: Invoices & Immutable Point-in-Time Line Items', () {
    test('historical invoice items preserve snapshot price and name when product changes', () async {
      final now = DateTime.now();

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-oil',
              name: 'Sunflower Oil 1L',
              sellingPrice: 100.0,
              updatedAt: now,
            ),
          );

      const invoiceId = 'inv-uuid-001';
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: 'INV-2026-001',
              deviceId: 'device-pos-1',
              employeeId: 'emp-1',
              subtotal: 200.0,
              totalAmount: 200.0,
              paymentMethod: 'cash',
              createdAt: now,
            ),
          );

      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-uuid-001',
              invoiceId: invoiceId,
              productId: const Value('prod-oil'),
              productName: 'Sunflower Oil 1L',
              quantity: 2.0,
              unitPrice: 100.0,
              lineTotal: 200.0,
            ),
          );

      await (db.update(db.products)..where((tbl) => tbl.id.equals('prod-oil'))).write(
        ProductsCompanion(
          name: const Value('Sunflower Oil 1L (Refined)'),
          sellingPrice: const Value(160.0),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final items = await db.getItemsForInvoice(invoiceId);
      expect(items.length, equals(1));
      expect(items.first.productName, equals('Sunflower Oil 1L'));
      expect(items.first.unitPrice, equals(100.0));
      expect(items.first.lineTotal, equals(200.0));

      final updatedCatalogProduct = await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-oil'))).getSingle();
      expect(updatedCatalogProduct.sellingPrice, equals(160.0));
    });

    test('deleting an invoice cascades to delete its invoice items', () async {
      const invoiceId = 'inv-uuid-cascade';
      final now = DateTime.now();

      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: invoiceId,
              invoiceNumber: 'INV-CASCADE',
              deviceId: 'dev-1',
              employeeId: 'emp-1',
              subtotal: 50.0,
              totalAmount: 50.0,
              paymentMethod: 'upi',
              createdAt: now,
            ),
          );

      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'cascade-item-1',
              invoiceId: invoiceId,
              productName: 'Soap',
              quantity: 1.0,
              unitPrice: 50.0,
              lineTotal: 50.0,
            ),
          );

      expect(await db.getItemsForInvoice(invoiceId), hasLength(1));

      await (db.delete(db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).go();

      expect(await db.getItemsForInvoice(invoiceId), isEmpty);
    });
  });

  group('AppDatabase - Slice 3: Atomic Checkout Transaction & Rollback', () {
    test('commits invoice, line items, delta movements, and sync queue atomically', () async {
      final now = DateTime.now();

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-apple',
              name: 'Kashmir Apples',
              sellingPrice: 150.0,
              stockQuantity: const Value(20.0),
              updatedAt: now,
            ),
          );

      const invoiceId = 'inv-atomic-01';
      final invoice = InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNumber: 'INV-1001',
        deviceId: 'terminal-01',
        employeeId: 'cashier-01',
        subtotal: 300.0,
        totalAmount: 300.0,
        paymentMethod: 'cash',
        createdAt: now,
      );

      final items = [
        InvoiceItemsCompanion.insert(
          id: 'item-atomic-01',
          invoiceId: invoiceId,
          productId: const Value('p-apple'),
          productName: 'Kashmir Apples',
          quantity: 2.0,
          unitPrice: 150.0,
          lineTotal: 300.0,
        ),
      ];

      final movements = [
        InventoryMovementsCompanion.insert(
          id: 'mov-atomic-01',
          productId: 'p-apple',
          deltaQuantity: -2.0,
          reason: 'sale',
          referenceId: const Value(invoiceId),
          createdAt: now,
        ),
      ];

      final syncQueueItem = SyncQueueCompanion.insert(
        id: 'sync-atomic-01',
        transactionId: invoiceId,
        operation: 'create_invoice',
        payload: '{"invoice_id": "$invoiceId"}',
        createdAt: now,
        updatedAt: now,
      );

      await db.recordCheckoutTransaction(
        invoice: invoice,
        items: items,
        movements: movements,
        syncQueueItem: syncQueueItem,
      );

      final savedInvoice = await (db.select(db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).getSingleOrNull();
      expect(savedInvoice, isNotNull);

      final savedItems = await db.getItemsForInvoice(invoiceId);
      expect(savedItems.length, equals(1));

      final savedMovements = await (db.select(db.inventoryMovements)..where((tbl) => tbl.referenceId.equals(invoiceId))).get();
      expect(savedMovements.length, equals(1));
      expect(savedMovements.first.deltaQuantity, equals(-2.0));

      final savedSync = await (db.select(db.syncQueue)..where((tbl) => tbl.transactionId.equals(invoiceId))).getSingleOrNull();
      expect(savedSync, isNotNull);
      expect(savedSync!.status, equals('pending'));
    });

    test('rolls back entire checkout transaction if any operation fails', () async {
      final now = DateTime.now();
      const invoiceId = 'inv-rollback-01';

      final invoice = InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNumber: 'INV-FAIL',
        deviceId: 'term-1',
        employeeId: 'emp-1',
        subtotal: 100.0,
        totalAmount: 100.0,
        paymentMethod: 'cash',
        createdAt: now,
      );

      final items = [
        InvoiceItemsCompanion.insert(
          id: 'item-ok',
          invoiceId: invoiceId,
          productName: 'Bread',
          quantity: 1.0,
          unitPrice: 100.0,
          lineTotal: 100.0,
        ),
      ];

      final invalidMovements = [
        InventoryMovementsCompanion.insert(
          id: 'mov-fail',
          productId: 'nonexistent-product-id',
          deltaQuantity: -1.0,
          reason: 'sale',
          referenceId: const Value(invoiceId),
          createdAt: now,
        ),
      ];

      final syncItem = SyncQueueCompanion.insert(
        id: 'sync-fail',
        transactionId: invoiceId,
        operation: 'create_invoice',
        payload: '{}',
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => db.recordCheckoutTransaction(
          invoice: invoice,
          items: items,
          movements: invalidMovements,
          syncQueueItem: syncItem,
        ),
        throwsA(isA<Exception>()),
      );

      final savedInvoice = await (db.select(db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).getSingleOrNull();
      expect(savedInvoice, isNull);

      final savedItems = await db.getItemsForInvoice(invoiceId);
      expect(savedItems, isEmpty);

      final savedSync = await (db.select(db.syncQueue)..where((tbl) => tbl.transactionId.equals(invoiceId))).getSingleOrNull();
      expect(savedSync, isNull);
    });
  });

  group('AppDatabase - Slice 4: Delta Inventory Movement Ledger', () {
    test('applies delta movements sequentially and reconciles inventory accurately', () async {
      final now = DateTime.now();
      const productId = 'prod-maggi';

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: productId,
              name: 'Maggi Noodles 4-pack',
              sellingPrice: 48.0,
              stockQuantity: const Value(10.0),
              updatedAt: now,
            ),
          );

      await db.applyInventoryDelta(
        movementId: 'mov-phone-1',
        productId: productId,
        deltaQuantity: -2.0,
        reason: 'sale',
        referenceId: 'inv-phone-1',
      );

      await db.applyInventoryDelta(
        movementId: 'mov-phone-2',
        productId: productId,
        deltaQuantity: -3.0,
        reason: 'sale',
        referenceId: 'inv-phone-2',
      );

      await db.applyInventoryDelta(
        movementId: 'mov-restock',
        productId: productId,
        deltaQuantity: 15.0,
        reason: 'restock',
        referenceId: 'po-999',
      );

      final updatedProduct = await (db.select(db.products)..where((tbl) => tbl.id.equals(productId))).getSingle();
      expect(updatedProduct.stockQuantity, equals(20.0));

      final history = await db.getInventoryHistoryForProduct(productId);
      expect(history.length, equals(3));
      expect(history.map((m) => m.deltaQuantity).toList(), equals([-2.0, -3.0, 15.0]));
    });
  });

  group('AppDatabase - Slice 5: Sync Queue State Transitions', () {
    test('transitions sync queue items from pending to synced upon acknowledgement', () async {
      final now = DateTime.now();
      const syncId = 'sq-01';

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: syncId,
              transactionId: 'inv-123',
              operation: 'upload_invoice',
              payload: '{"items": 5}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Check pending
      final pending = await db.getPendingSyncItems();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(syncId));

      // Mark success
      await db.markSyncItemSuccess(syncId);

      // Verify no longer pending
      expect(await db.getPendingSyncItems(), isEmpty);

      // Verify database record updated to 'synced'
      final record = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(syncId))).getSingle();
      expect(record.status, equals('synced'));
    });

    test('records sync error and increments retry count on failure', () async {
      final now = DateTime.now();
      const syncId = 'sq-02';

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: syncId,
              transactionId: 'inv-456',
              operation: 'upload_invoice',
              payload: '{"items": 2}',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Record failure
      await db.recordSyncItemFailure(syncId, 'Connection timeout to desktop');

      final record = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(syncId))).getSingle();
      expect(record.status, equals('error'));
      expect(record.retryCount, equals(1));
      expect(record.lastError, equals('Connection timeout to desktop'));
    });
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Products,
  Employees,
  Invoices,
  InvoiceItems,
  InventoryMovements,
  SyncQueue,
  Devices,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.inMemory()
      : super(
          NativeDatabase.memory(
            setup: (rawDb) {
              rawDb.execute('PRAGMA foreign_keys = ON;');
            },
          ),
        );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  // Product DAOs
  Future<Product?> getProductByBarcode(String barcode) {
    return (select(products)..where((tbl) => tbl.barcode.equals(barcode))).getSingleOrNull();
  }

  Future<List<Product>> getActiveProducts() {
    return (select(products)..where((tbl) => tbl.isActive.equals(true))).get();
  }

  Future<List<Product>> searchProducts(String query) {
    final term = '%$query%';
    return (select(products)
          ..where((tbl) =>
              tbl.isActive.equals(true) &
              (tbl.name.like(term) | tbl.barcode.like(term) | tbl.sku.like(term))))
        .get();
  }

  // Invoice DAOs
  Future<List<InvoiceItem>> getItemsForInvoice(String invoiceId) {
    return (select(invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId))).get();
  }

  /// Atomically commits an entire checkout transaction:
  /// invoice header, line items, delta movements, and sync queue entry.
  /// If any operation fails, the entire transaction rolls back cleanly.
  Future<void> recordCheckoutTransaction({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
    required List<InventoryMovementsCompanion> movements,
    required SyncQueueCompanion syncQueueItem,
  }) {
    return transaction(() async {
      await into(invoices).insert(invoice);
      for (final item in items) {
        await into(invoiceItems).insert(item);
      }
      for (final movement in movements) {
        await into(inventoryMovements).insert(movement);
      }
      await into(syncQueue).insert(syncQueueItem);
    });
  }

  /// Applies a signed delta movement to the product's stock and writes to the movement audit log.
  Future<void> applyInventoryDelta({
    required String movementId,
    required String productId,
    required double deltaQuantity,
    required String reason,
    String? referenceId,
    DateTime? createdAt,
  }) {
    return transaction(() async {
      final now = createdAt ?? DateTime.now();

      await into(inventoryMovements).insert(
        InventoryMovementsCompanion.insert(
          id: movementId,
          productId: productId,
          deltaQuantity: deltaQuantity,
          reason: reason,
          referenceId: Value(referenceId),
          createdAt: now,
        ),
      );

      final product = await (select(products)..where((tbl) => tbl.id.equals(productId))).getSingle();
      final newStock = product.stockQuantity + deltaQuantity;

      await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newStock),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Retrieves audit log of inventory movements for a product ordered chronologically.
  Future<List<InventoryMovement>> getInventoryHistoryForProduct(String productId) {
    return (select(inventoryMovements)
          ..where((tbl) => tbl.productId.equals(productId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  // Sync Queue DAOs
  Future<List<SyncQueueData>> getPendingSyncItems() {
    return (select(syncQueue)
          ..where((tbl) => tbl.status.equals('pending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  Future<void> markSyncItemSuccess(String syncId) {
    return (update(syncQueue)..where((tbl) => tbl.id.equals(syncId))).write(
      SyncQueueCompanion(
        status: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> recordSyncItemFailure(String syncId, String error) async {
    final item = await (select(syncQueue)..where((tbl) => tbl.id.equals(syncId))).getSingle();
    await (update(syncQueue)..where((tbl) => tbl.id.equals(syncId))).write(
      SyncQueueCompanion(
        status: const Value('error'),
        retryCount: Value(item.retryCount + 1),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

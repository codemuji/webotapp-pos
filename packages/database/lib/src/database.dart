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

  /// Idempotently ingests an invoice received from a remote mobile terminal.
  /// If the invoice ID already exists, it is treated as a duplicate ACK (no-op).
  /// If new, it saves the invoice, items, and creates signed delta inventory movements
  /// to reconcile central stock without overwrite bugs.
  Future<SyncIngestResult> ingestSyncedInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
  }) async {
    final existing = await (select(invoices)..where((tbl) => tbl.id.equals(invoice.id.value))).getSingleOrNull();
    if (existing != null) {
      return SyncIngestResult(
        isDuplicate: true,
        invoiceId: invoice.id.value,
        itemsCount: 0,
      );
    }

    return transaction(() async {
      await into(invoices).insert(invoice);

      for (final item in items) {
        await into(invoiceItems).insert(item);

        if (item.productId.present && item.productId.value != null) {
          final prodId = item.productId.value!;
          final prod = await (select(products)..where((tbl) => tbl.id.equals(prodId))).getSingleOrNull();
          if (prod != null) {
            final movId = 'mov-sync-${invoice.id.value}-${item.id.value}';
            final qty = item.quantity.value;
            await into(inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                id: movId,
                productId: prodId,
                deltaQuantity: -qty,
                reason: 'synced_sale',
                referenceId: Value(invoice.id.value),
                createdAt: invoice.createdAt.value,
              ),
            );

            final newStock = prod.stockQuantity - qty;
            await (update(products)..where((tbl) => tbl.id.equals(prodId))).write(
              ProductsCompanion(
                stockQuantity: Value(newStock),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }

      return SyncIngestResult(
        isDuplicate: false,
        invoiceId: invoice.id.value,
        itemsCount: items.length,
      );
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

  // Admin Catalog & Category DAOs
  Future<List<Product>> getAllProducts() {
    return select(products).get();
  }

  Future<void> upsertProduct(ProductsCompanion product) {
    return into(products).insertOnConflictUpdate(product);
  }

  Future<void> toggleProductActive(String productId, bool isActive) {
    return (update(products)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Category>> getAllCategories() {
    return select(categories).get();
  }

  Future<void> upsertCategory(CategoriesCompanion category) {
    return into(categories).insertOnConflictUpdate(category);
  }

  Future<int> deleteCategory(String categoryId) {
    return (delete(categories)..where((tbl) => tbl.id.equals(categoryId))).go();
  }

  // Employee Management DAOs
  Future<List<Employee>> getAllEmployees() {
    return select(employees).get();
  }

  Future<void> upsertEmployee(EmployeesCompanion employee) {
    return into(employees).insertOnConflictUpdate(employee);
  }

  Future<bool> verifyEmployeePin(String employeeId, String pin) async {
    final employee = await (select(employees)..where((tbl) => tbl.id.equals(employeeId))).getSingleOrNull();
    if (employee == null || !employee.isActive) {
      return false;
    }
    return employee.pinHash == pin;
  }

  // Device Pairing DAOs
  Future<List<Device>> getAllDevices() {
    return select(devices).get();
  }

  Future<void> upsertDevice(DevicesCompanion device) {
    return into(devices).insertOnConflictUpdate(device);
  }

  Future<Device?> getDeviceByToken(String token) {
    return (select(devices)..where((tbl) => tbl.pairingToken.equals(token) & tbl.isPaired.equals(true))).getSingleOrNull();
  }

  Future<void> updateDeviceSyncTime(String deviceId, DateTime syncTime) {
    return (update(devices)..where((tbl) => tbl.id.equals(deviceId))).write(
      DevicesCompanion(
        lastSyncedAt: Value(syncTime),
      ),
    );
  }

  // Dashboard & Reporting Metrics DAOs
  Future<DashboardMetrics> getDashboardMetrics({DateTime? startDate, DateTime? endDate}) async {
    var query = select(invoices);
    if (startDate != null) {
      query = query..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query..where((tbl) => tbl.createdAt.isSmallerOrEqualValue(endDate));
    }

    final invoiceList = await query.get();

    double totalRevenue = 0.0;
    final paymentBreakdown = <String, double>{};
    final cashierBreakdown = <String, double>{};

    for (final inv in invoiceList) {
      totalRevenue += inv.totalAmount;

      paymentBreakdown[inv.paymentMethod] = (paymentBreakdown[inv.paymentMethod] ?? 0.0) + inv.totalAmount;
      cashierBreakdown[inv.employeeId] = (cashierBreakdown[inv.employeeId] ?? 0.0) + inv.totalAmount;
    }

    final orderCount = invoiceList.length;
    final aov = orderCount > 0 ? totalRevenue / orderCount : 0.0;

    return DashboardMetrics(
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      averageOrderValue: aov,
      paymentBreakdown: paymentBreakdown,
      cashierBreakdown: cashierBreakdown,
    );
  }
}

/// Result of an idempotent synced invoice ingestion.
class SyncIngestResult {
  final bool isDuplicate;
  final String invoiceId;
  final int itemsCount;

  const SyncIngestResult({
    required this.isDuplicate,
    required this.invoiceId,
    required this.itemsCount,
  });
}

/// Aggregated executive dashboard metrics for revenue, order count, and payment breakdown.
class DashboardMetrics {
  final double totalRevenue;
  final int orderCount;
  final double averageOrderValue;
  final Map<String, double> paymentBreakdown;
  final Map<String, double> cashierBreakdown;

  const DashboardMetrics({
    required this.totalRevenue,
    required this.orderCount,
    required this.averageOrderValue,
    required this.paymentBreakdown,
    required this.cashierBreakdown,
  });
}

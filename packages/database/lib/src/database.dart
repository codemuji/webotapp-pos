import 'dart:io';
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

  AppDatabase.fromFile(File file)
      : super(
          NativeDatabase(
            file,
            setup: (rawDb) {
              rawDb.execute('PRAGMA foreign_keys = ON;');
            },
          ),
        );

  @override
  int get schemaVersion => 3;

  Future<void> _safeAddColumn(String table, String column, String typeWithDefault) async {
    try {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $typeWithDefault;');
    } catch (_) {
      // Column may already exist or table already has it
    }
  }

  Future<void> _ensureSchemaV2() async {
    // Categories new columns
    await _safeAddColumn('categories', 'default_tax_rate', 'REAL NOT NULL DEFAULT 0.0');
    await _safeAddColumn('categories', 'default_hsn_code', 'TEXT');

    // Products new columns
    await _safeAddColumn('products', 'secondary_barcode', 'TEXT');
    await _safeAddColumn('products', 'parent_product_id', 'TEXT');
    await _safeAddColumn('products', 'variant_name', 'TEXT');
    await _safeAddColumn('products', 'tax_rate', 'REAL NOT NULL DEFAULT 0.0');
    await _safeAddColumn('products', 'hsn_code', 'TEXT');
    await _safeAddColumn('products', 'min_stock_alert', 'REAL NOT NULL DEFAULT 5.0');

    // Safe backfill of null values for non-nullable Drift fields
    try {
      await customStatement('UPDATE products SET tax_rate = 0.0 WHERE tax_rate IS NULL;');
      await customStatement('UPDATE products SET min_stock_alert = 5.0 WHERE min_stock_alert IS NULL;');
      await customStatement('UPDATE categories SET default_tax_rate = 0.0 WHERE default_tax_rate IS NULL;');
    } catch (_) {}
  }

  Future<void> _ensureSchemaV3() async {
    await _ensureSchemaV2();
    await _safeAddColumn('products', 'expiry_date', 'INTEGER');
    await _safeAddColumn('products', 'batch_number', 'TEXT');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await _ensureSchemaV3();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _ensureSchemaV2();
          }
          if (from < 3) {
            await _ensureSchemaV3();
          }
        },
      );

  // Product DAOs
  Future<Product?> getProductByBarcode(String barcode) {
    return (select(products)
          ..where((tbl) =>
              (tbl.barcode.equals(barcode) | tbl.secondaryBarcode.equals(barcode)) &
              tbl.isActive.equals(true)))
        .getSingleOrNull();
  }

  Future<List<Product>> getProductsByBarcode(String barcode) {
    return (select(products)
          ..where((tbl) =>
              (tbl.barcode.equals(barcode) | tbl.secondaryBarcode.equals(barcode)) &
              tbl.isActive.equals(true)))
        .get();
  }

  Future<List<Product>> getVariantsForProduct(String parentProductId) {
    return (select(products)
          ..where((tbl) => tbl.parentProductId.equals(parentProductId) & tbl.isActive.equals(true)))
        .get();
  }

  Future<List<Product>> getLowStockProducts() {
    return (select(products)
          ..where((tbl) => tbl.isActive.equals(true) & tbl.stockQuantity.isSmallerOrEqual(tbl.minStockAlert))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.stockQuantity, mode: OrderingMode.asc)]))
        .get();
  }

  Future<List<Product>> getExpiringProducts({int days = 30}) {
    final cutoff = DateTime.now().add(Duration(days: days));
    return (select(products)
          ..where((tbl) =>
              tbl.isActive.equals(true) &
              tbl.expiryDate.isNotNull() &
              tbl.expiryDate.isSmallerOrEqualValue(cutoff))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.expiryDate, mode: OrderingMode.asc)]))
        .get();
  }

  Future<List<Product>> getExpiredProducts() {
    final now = DateTime.now();
    return (select(products)
          ..where((tbl) =>
              tbl.isActive.equals(true) &
              tbl.expiryDate.isNotNull() &
              tbl.expiryDate.isSmallerThanValue(now))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.expiryDate, mode: OrderingMode.asc)]))
        .get();
  }

  Future<void> recordStockAdjustment({
    required String productId,
    required double deltaQuantity,
    required String reason,
    String? referenceId,
  }) {
    return transaction(() async {
      final prod = await (select(products)..where((tbl) => tbl.id.equals(productId))).getSingleOrNull();
      if (prod == null) return;

      final newQty = (prod.stockQuantity + deltaQuantity).clamp(0.0, 999999.0);
      final movId = 'mov-${DateTime.now().millisecondsSinceEpoch}-${productId.hashCode.abs()}';

      await into(inventoryMovements).insert(
        InventoryMovementsCompanion.insert(
          id: movId,
          productId: productId,
          deltaQuantity: deltaQuantity,
          reason: reason,
          referenceId: Value(referenceId),
          createdAt: DateTime.now(),
        ),
      );

      await (update(products)..where((tbl) => tbl.id.equals(productId))).write(
        ProductsCompanion(
          stockQuantity: Value(newQty),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<Product>> getActiveProducts() {
    return (select(products)..where((tbl) => tbl.isActive.equals(true))).get();
  }

  Future<List<Product>> searchProducts(String query) {
    final term = '%$query%';
    return (select(products)
          ..where((tbl) =>
              tbl.isActive.equals(true) &
              (tbl.name.like(term) |
                  tbl.barcode.like(term) |
                  tbl.secondaryBarcode.like(term) |
                  tbl.sku.like(term) |
                  tbl.variantName.like(term))))
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
          ..where((tbl) => tbl.status.equals('pending') | tbl.status.equals('error'))
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

  /// Permanently deletes a single product and associated movements, safely unlinking historical invoice items.
  Future<int> deleteProduct(String productId) {
    return bulkDeleteProducts([productId]);
  }

  /// Bulk deletes a list of products by ID, unlinking variants and historical invoices atomically.
  Future<int> bulkDeleteProducts(List<String> productIds) {
    if (productIds.isEmpty) return Future.value(0);
    return transaction(() async {
      await (update(products)..where((tbl) => tbl.parentProductId.isIn(productIds))).write(
        const ProductsCompanion(parentProductId: Value(null)),
      );
      await (update(invoiceItems)..where((tbl) => tbl.productId.isIn(productIds))).write(
        const InvoiceItemsCompanion(productId: Value(null)),
      );
      await (delete(inventoryMovements)..where((tbl) => tbl.productId.isIn(productIds))).go();
      return (delete(products)..where((tbl) => tbl.id.isIn(productIds))).go();
    });
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
    final hourlySales = <String, double>{
      '08:00': 0.0,
      '10:00': 0.0,
      '12:00': 0.0,
      '14:00': 0.0,
      '16:00': 0.0,
      '18:00': 0.0,
      '20:00': 0.0,
      '22:00': 0.0,
    };

    for (final inv in invoiceList) {
      totalRevenue += inv.totalAmount;

      paymentBreakdown[inv.paymentMethod] = (paymentBreakdown[inv.paymentMethod] ?? 0.0) + inv.totalAmount;
      cashierBreakdown[inv.employeeId] = (cashierBreakdown[inv.employeeId] ?? 0.0) + inv.totalAmount;

      final h = inv.createdAt.hour;
      String bucket;
      if (h < 9) {
        bucket = '08:00';
      } else if (h < 11) {
        bucket = '10:00';
      } else if (h < 13) {
        bucket = '12:00';
      } else if (h < 15) {
        bucket = '14:00';
      } else if (h < 17) {
        bucket = '16:00';
      } else if (h < 19) {
        bucket = '18:00';
      } else if (h < 21) {
        bucket = '20:00';
      } else {
        bucket = '22:00';
      }
      hourlySales[bucket] = (hourlySales[bucket] ?? 0.0) + inv.totalAmount;
    }

    final orderCount = invoiceList.length;
    final aov = orderCount > 0 ? totalRevenue / orderCount : 0.0;

    return DashboardMetrics(
      totalRevenue: totalRevenue,
      orderCount: orderCount,
      averageOrderValue: aov,
      paymentBreakdown: paymentBreakdown,
      cashierBreakdown: cashierBreakdown,
      hourlySales: hourlySales,
    );
  }

  // Invoices & Sales Reporting DAOs
  Future<List<Invoice>> getAllInvoices({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    int? limit,
    int? offset,
  }) async {
    var query = select(invoices);
    if (startDate != null) {
      query = query..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query = query..where((tbl) => tbl.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod != 'all') {
      query = query..where((tbl) => tbl.paymentMethod.equals(paymentMethod));
    }
    query = query..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }
    return query.get();
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) {
    return (select(invoiceItems)..where((tbl) => tbl.invoiceId.equals(invoiceId))).get();
  }

  Future<InvoiceWithItems?> getInvoiceWithItems(String invoiceId) async {
    final inv = await (select(invoices)..where((tbl) => tbl.id.equals(invoiceId))).getSingleOrNull();
    if (inv == null) return null;
    final items = await getInvoiceItems(invoiceId);
    return InvoiceWithItems(invoice: inv, items: items);
  }

  /// High-performance batch retrieval of invoices and line items.
  /// Eliminates the N+1 query storm by executing exactly 2 queries: one for invoices,
  /// and one batch query for all corresponding line items.
  Future<List<InvoiceWithItems>> getAllInvoicesWithItems({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    int? limit,
    int? offset,
  }) async {
    final invs = await getAllInvoices(
      startDate: startDate,
      endDate: endDate,
      paymentMethod: paymentMethod,
      limit: limit,
      offset: offset,
    );
    if (invs.isEmpty) return const [];

    final invIds = invs.map((i) => i.id).toList();
    final allItems = await (select(invoiceItems)..where((tbl) => tbl.invoiceId.isIn(invIds))).get();

    final itemMap = <String, List<InvoiceItem>>{};
    for (final item in allItems) {
      itemMap.putIfAbsent(item.invoiceId, () => []).add(item);
    }

    return invs.map((inv) {
      return InvoiceWithItems(invoice: inv, items: itemMap[inv.id] ?? const []);
    }).toList();
  }

  Future<List<InvoiceWithItems>> getRecentInvoicesWithItems({int limit = 10}) {
    return getAllInvoicesWithItems(limit: limit);
  }

  /// Permanently deletes an invoice and its line items.
  Future<int> deleteInvoice(String invoiceId) {
    return bulkDeleteInvoices([invoiceId]);
  }

  /// Bulk deletes invoices and their associated line items atomically.
  Future<int> bulkDeleteInvoices(List<String> invoiceIds) {
    if (invoiceIds.isEmpty) return Future.value(0);
    return transaction(() async {
      await (delete(invoiceItems)..where((tbl) => tbl.invoiceId.isIn(invoiceIds))).go();
      await (delete(inventoryMovements)..where((tbl) => tbl.referenceId.isIn(invoiceIds))).go();
      return (delete(invoices)..where((tbl) => tbl.id.isIn(invoiceIds))).go();
    });
  }
}

/// A synced or recorded invoice paired with its immutable line items.
class InvoiceWithItems {
  final Invoice invoice;
  final List<InvoiceItem> items;

  const InvoiceWithItems({
    required this.invoice,
    required this.items,
  });

  int get itemsCount => items.length;
  double get totalQuantity => items.fold(0.0, (sum, i) => sum + i.quantity);
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
  final Map<String, double> hourlySales;

  const DashboardMetrics({
    required this.totalRevenue,
    required this.orderCount,
    required this.averageOrderValue,
    required this.paymentBreakdown,
    required this.cashierBreakdown,
    this.hourlySales = const {},
  });
}

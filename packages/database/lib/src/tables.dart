import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get defaultTaxRate => real().withDefault(const Constant(0.0))();
  TextColumn get defaultHsnCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get secondaryBarcode => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get categoryId => text().nullable().customConstraint('REFERENCES categories(id)')();
  RealColumn get sellingPrice => real()();
  RealColumn get purchasePrice => real().nullable()();
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  TextColumn get parentProductId => text().nullable()();
  TextColumn get variantName => text().nullable()();
  RealColumn get taxRate => real().withDefault(const Constant(0.0))();
  TextColumn get hsnCode => text().nullable()();
  RealColumn get minStockAlert => real().withDefault(const Constant(5.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Employees extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pinHash => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get invoiceNumber => text()();
  TextColumn get deviceId => text()();
  TextColumn get employeeId => text()();
  TextColumn get customerId => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}

class InvoiceItems extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get invoiceId => text().customConstraint('NOT NULL REFERENCES invoices(id) ON DELETE CASCADE')();
  TextColumn get productId => text().nullable().customConstraint('REFERENCES products(id)')();
  TextColumn get productName => text()();
  TextColumn get barcode => text().nullable()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class InventoryMovements extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get productId => text().customConstraint('NOT NULL REFERENCES products(id)')();
  RealColumn get deltaQuantity => real()(); // e.g. -2.0 for sale, +10.0 for restock
  TextColumn get reason => text()(); // 'sale', 'restock', 'adjustment', 'return'
  TextColumn get referenceId => text().nullable()(); // invoiceId or purchaseOrderId
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get transactionId => text()();
  TextColumn get operation => text()(); // 'insert_invoice', 'update_stock', etc.
  TextColumn get payload => text()(); // JSON payload
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, synced, error
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get deviceName => text()();
  TextColumn get pairingToken => text()();
  BoolColumn get isPaired => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

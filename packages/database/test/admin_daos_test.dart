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

  group('AppDatabase - Slice 1: Admin Catalog, Categories, Employees & Metrics DAOs', () {
    test('creates and retrieves categories with hierarchy', () async {
      await db.upsertCategory(
        CategoriesCompanion.insert(
          id: 'cat-dairy',
          name: 'Dairy & Eggs',
          description: const Value('Milk, cheese, butter, eggs'),
        ),
      );

      final categories = await db.getAllCategories();
      expect(categories.length, equals(1));
      expect(categories.first.name, equals('Dairy & Eggs'));
    });

    test('creates, updates, and deactivates catalog products', () async {
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-butter',
          name: 'Amul Butter 100g',
          sellingPrice: 58.0,
          purchasePrice: const Value(48.0),
          stockQuantity: const Value(25.0),
          updatedAt: DateTime.now(),
        ),
      );

      var products = await db.getAllProducts();
      expect(products.length, equals(1));
      expect(products.first.sellingPrice, equals(58.0));
      expect(products.first.purchasePrice, equals(48.0));
      expect(products.first.isActive, isTrue);

      // Deactivate product
      await db.toggleProductActive('p-butter', false);
      products = await db.getAllProducts();
      expect(products.first.isActive, isFalse);

      final activeOnly = await db.getActiveProducts();
      expect(activeOnly, isEmpty);
    });

    test('creates employee with PIN hash and verifies credentials', () async {
      await db.upsertEmployee(
        EmployeesCompanion.insert(
          id: 'emp-101',
          name: 'Priya Sharma',
          pinHash: '1234', // In production, salted hash
          role: const Value('cashier'),
          createdAt: DateTime.now(),
        ),
      );

      final employees = await db.getAllEmployees();
      expect(employees.length, equals(1));
      expect(employees.first.name, equals('Priya Sharma'));

      final isValid = await db.verifyEmployeePin('emp-101', '1234');
      final isInvalid = await db.verifyEmployeePin('emp-101', '9999');

      expect(isValid, isTrue);
      expect(isInvalid, isFalse);
    });

    test('calculates dashboard metrics aggregating revenue and payment breakdown', () async {
      final now = DateTime.now();

      // Insert two invoices
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-1',
              invoiceNumber: 'INV-001',
              deviceId: 'term-01',
              employeeId: 'emp-101',
              subtotal: 100.0,
              totalAmount: 100.0,
              paymentMethod: 'cash',
              createdAt: now,
            ),
          );

      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-2',
              invoiceNumber: 'INV-002',
              deviceId: 'term-01',
              employeeId: 'emp-102',
              subtotal: 200.0,
              totalAmount: 200.0,
              paymentMethod: 'upi_qr',
              createdAt: now,
            ),
          );

      final metrics = await db.getDashboardMetrics();

      expect(metrics.totalRevenue, equals(300.0));
      expect(metrics.orderCount, equals(2));
      expect(metrics.averageOrderValue, equals(150.0));
      expect(metrics.paymentBreakdown['cash'], equals(100.0));
      expect(metrics.paymentBreakdown['upi_qr'], equals(200.0));
      expect(metrics.cashierBreakdown['emp-101'], equals(100.0));
      expect(metrics.cashierBreakdown['emp-102'], equals(200.0));
    });

    test('getLowStockProducts retrieves products whose stockQuantity <= minStockAlert', () async {
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-bread',
          name: 'Whole Wheat Bread',
          sellingPrice: 40.0,
          stockQuantity: const Value(2.0),
          minStockAlert: const Value(5.0),
          updatedAt: DateTime.now(),
        ),
      );
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-flour',
          name: 'Atta Flour 5kg',
          sellingPrice: 280.0,
          stockQuantity: const Value(20.0),
          minStockAlert: const Value(5.0),
          updatedAt: DateTime.now(),
        ),
      );

      final lowStock = await db.getLowStockProducts();
      expect(lowStock.length, equals(1));
      expect(lowStock.first.id, equals('p-bread'));
    });

    test('getExpiringProducts and getExpiredProducts filter by cutoff and expiration dates', () async {
      final now = DateTime.now();
      // Expired 2 days ago
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-milk-expired',
          name: 'Fresh Cow Milk 500ml',
          sellingPrice: 32.0,
          expiryDate: Value(now.subtract(const Duration(days: 2))),
          updatedAt: now,
        ),
      );
      // Expiring in 5 days
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-yogurt-soon',
          name: 'Greek Yogurt 200g',
          sellingPrice: 65.0,
          expiryDate: Value(now.add(const Duration(days: 5))),
          updatedAt: now,
        ),
      );
      // Expiring in 60 days
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-rice-safe',
          name: 'Basmati Rice 1kg',
          sellingPrice: 120.0,
          expiryDate: Value(now.add(const Duration(days: 60))),
          updatedAt: now,
        ),
      );

      final expired = await db.getExpiredProducts();
      expect(expired.length, equals(1));
      expect(expired.first.id, equals('p-milk-expired'));

      final expiring30d = await db.getExpiringProducts(days: 30);
      expect(expiring30d.length, equals(2)); // Both expired and expiring in 5 days
      expect(expiring30d.any((p) => p.id == 'p-yogurt-soon'), isTrue);
    });

    test('recordStockAdjustment updates stockQuantity and logs inventory movement', () async {
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-oil',
          name: 'Mustard Oil 1L',
          sellingPrice: 160.0,
          stockQuantity: const Value(10.0),
          updatedAt: DateTime.now(),
        ),
      );

      // Restock +15 units
      await db.recordStockAdjustment(
        productId: 'p-oil',
        deltaQuantity: 15.0,
        reason: 'restock',
      );

      var p = await (db.select(db.products)..where((t) => t.id.equals('p-oil'))).getSingle();
      expect(p.stockQuantity, equals(25.0));

      final movements = await db.select(db.inventoryMovements).get();
      expect(movements.length, equals(1));
      expect(movements.first.reason, equals('restock'));
      expect(movements.first.deltaQuantity, equals(15.0));
    });

    test('bulkDeleteProducts unlinks foreign keys and removes selected products', () async {
      final now = DateTime.now();
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-del-1',
          name: 'Item 1',
          sellingPrice: 10.0,
          updatedAt: now,
        ),
      );
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-del-2',
          name: 'Item 2',
          sellingPrice: 20.0,
          updatedAt: now,
        ),
      );
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'p-keep',
          name: 'Item Keep',
          sellingPrice: 30.0,
          updatedAt: now,
        ),
      );

      final count = await db.bulkDeleteProducts(['p-del-1', 'p-del-2']);
      expect(count, equals(2));

      final remaining = await db.getAllProducts();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('p-keep'));
    });

    test('bulkDeleteInvoices removes invoices and line items atomically', () async {
      final now = DateTime.now();
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: 'inv-del-1',
              invoiceNumber: 'INV-DEL-1',
              deviceId: 'term-01',
              employeeId: 'emp-101',
              subtotal: 50.0,
              totalAmount: 50.0,
              paymentMethod: 'cash',
              createdAt: now,
            ),
          );
      await db.into(db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: 'item-del-1',
              invoiceId: 'inv-del-1',
              productName: 'Sample',
              quantity: 1,
              unitPrice: 50.0,
              lineTotal: 50.0,
            ),
          );

      final count = await db.bulkDeleteInvoices(['inv-del-1']);
      expect(count, equals(1));

      final remainingInvs = await db.getAllInvoices();
      expect(remainingInvs, isEmpty);

      final remainingItems = await db.select(db.invoiceItems).get();
      expect(remainingItems, isEmpty);
    });
  });
}

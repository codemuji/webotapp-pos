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
  });
}

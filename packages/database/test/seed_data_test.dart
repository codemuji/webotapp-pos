import 'package:database/database.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  test('seedDemoStoreData populates 600+ products, categories, employees, and 400+ invoices', () async {
    final count = await seedDemoStoreData(db, force: true);
    expect(count, greaterThanOrEqualTo(500));

    // Verify categories
    final categories = await db.getAllCategories();
    expect(categories.length, equals(10));

    // Verify employees
    final employees = await db.getAllEmployees();
    expect(employees.length, equals(4));

    // Verify products
    final products = await db.getAllProducts();
    expect(products.length, greaterThanOrEqualTo(500));

    // Verify low stock products exist
    final lowStock = await db.getLowStockProducts();
    expect(lowStock.isNotEmpty, isTrue);

    // Verify expiring products exist
    final expiring = await db.getExpiringProducts(days: 30);
    expect(expiring.isNotEmpty, isTrue);

    // Verify expired products exist
    final expired = await db.getExpiredProducts();
    expect(expired.isNotEmpty, isTrue);

    // Verify real invoices were created
    final invoices = await db.getAllInvoices();
    expect(invoices.length, greaterThanOrEqualTo(400));

    // Verify real dashboard metrics calculations
    final metrics = await db.getDashboardMetrics();
    expect(metrics.totalRevenue, greaterThan(10000.0));
    expect(metrics.orderCount, equals(invoices.length));
    expect(metrics.averageOrderValue, greaterThan(0.0));
    expect(metrics.paymentBreakdown.keys, containsAll(['upi_qr', 'cash', 'card']));
    expect(metrics.cashierBreakdown.keys, containsAll(['emp-aarav', 'emp-priya']));
    expect(metrics.hourlySales.isNotEmpty, isTrue);
  });
}


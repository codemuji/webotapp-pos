import 'dart:io';
import 'package:database/database.dart';

/// Monorepo CLI utility to seed the local Windows and Android databases
/// with 540+ products, categories, employees, and 460+ completed sales invoices.
void main() async {
  final dbPaths = [
    r'C:\Users\codemuji\AppData\Roaming\WebotApp\WebotApp POS\grocery_pos_admin.db',
    r'C:\Users\codemuji\AppData\Roaming\com.grocerypos\desktop\grocery_pos_admin.db',
  ];

  for (final p in dbPaths) {
    final file = File(p);
    if (file.existsSync()) {
      print('Seeding database at: $p');
      final db = AppDatabase.fromFile(file);
      try {
        final count = await seedDemoStoreData(db, force: true);
        final invs = await db.getAllInvoices();
        final metrics = await db.getDashboardMetrics();
        print('✓ Seeded $count products, ${invs.length} invoices. Total revenue: ₹${metrics.totalRevenue.toStringAsFixed(2)}');
      } catch (e, st) {
        print('Error seeding $p: $e\n$st');
      } finally {
        await db.close();
      }
    }
  }
}


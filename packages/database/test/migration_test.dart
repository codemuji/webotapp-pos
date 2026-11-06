import 'dart:io';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:test/test.dart';

void main() {
  group('Schema Migration v1 to v2', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pos_migration_test_');
      dbFile = File('${tempDir.path}/test_v1.db');

      // Create a raw SQLite database matching schema version 1
      final rawDb = raw_sqlite.sqlite3.open(dbFile.path);
      rawDb.execute('''
        PRAGMA user_version = 1;
        CREATE TABLE categories (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT
        );
        CREATE TABLE products (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          barcode TEXT,
          sku TEXT,
          category_id TEXT REFERENCES categories(id),
          selling_price REAL NOT NULL,
          purchase_price REAL,
          stock_quantity REAL NOT NULL DEFAULT 0.0,
          unit TEXT NOT NULL DEFAULT 'pcs',
          is_active INTEGER NOT NULL DEFAULT 1,
          updated_at INTEGER NOT NULL
        );
        INSERT INTO products (id, name, barcode, sku, selling_price, purchase_price, stock_quantity, unit, is_active, updated_at)
        VALUES ('prod-v1-001', 'Test Product Legacy', '8901234567890', 'SKU-001', 50.0, 30.0, 10.0, 'pcs', 1, 1690000000);
      ''');
      rawDb.dispose();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('successfully upgrades schema from v1 to v2 and loads legacy products without null error', () async {
      final db = AppDatabase.fromFile(dbFile);

      // Fetch products - should not throw 'Null check operator used on a null value'
      final products = await db.getAllProducts();
      expect(products.length, equals(1));

      final p = products.first;
      expect(p.id, equals('prod-v1-001'));
      expect(p.name, equals('Test Product Legacy'));
      expect(p.taxRate, equals(0.0));
      expect(p.minStockAlert, equals(5.0));
      expect(p.variantName, isNull);
      expect(p.secondaryBarcode, isNull);

      // Verify inserting new product with v2 fields works
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-v2-002',
          name: 'Sugar',
          variantName: const Value('5kg Pack'),
          barcode: const Value('8901112223334'),
          sellingPrice: 220.0,
          taxRate: const Value(5.0),
          minStockAlert: const Value(15.0),
          updatedAt: DateTime.now(),
        ),
      );

      final updatedProducts = await db.getAllProducts();
      expect(updatedProducts.length, equals(2));

      await db.close();
    });
  });
}

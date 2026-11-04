import 'dart:convert';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase desktopDb;
  late AppDatabase mobileDbA;
  late AppDatabase mobileDbB;
  late SyncServer server;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    desktopDb = AppDatabase.inMemory();
    mobileDbA = AppDatabase.inMemory();
    mobileDbB = AppDatabase.inMemory();

    server = SyncServer(
      database: desktopDb,
      storeName: 'FreshMart Central Node',
    );
    await server.start(host: '127.0.0.1', port: 0);
  });

  tearDown(() async {
    await server.stop();
    await desktopDb.close();
    await mobileDbA.close();
    await mobileDbB.close();
  });

  group('SyncProtocol - Slice 5: Multi-Terminal Concurrency, Delta Reconciliation & Retry Integration Test', () {
    test('concurrent offline sales of same SKU reconcile without stock overwrite bugs or lost sales', () async {
      // 1. Initialize desktop catalog: Category 'Beverages' and Product 'Coffee 500g' with stock = 20.0
      await desktopDb.upsertCategory(CategoriesCompanion.insert(id: 'cat-bev', name: 'Beverages'));
      await desktopDb.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-coffee',
          name: 'Premium Roast Coffee 500g',
          barcode: const Value('890123400001'),
          categoryId: const Value('cat-bev'),
          sellingPrice: 250.0,
          stockQuantity: const Value(20.0),
          unit: const Value('tin'),
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Pair Terminal A and Terminal B
      final qr = server.generatePairingQrPayload(host: '127.0.0.1');

      final pairResA = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'terminal-mobile-A',
          'deviceName': 'Counter 1 Tablet',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final tokenA = jsonDecode(pairResA.body)['bearerToken'] as String;

      final pairResB = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'terminal-mobile-B',
          'deviceName': 'Counter 2 Tablet',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final tokenB = jsonDecode(pairResB.body)['bearerToken'] as String;

      // 3. Simulate offline checkout on Terminal A: 3 tins of Coffee sold
      final nowA = DateTime.now();
      final invIdA = 'inv-termA-001';
      await mobileDbA.into(mobileDbA.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'sync-A-1',
          transactionId: invIdA,
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {
              'id': invIdA,
              'invoiceNumber': 'INV-A-001',
              'deviceId': 'terminal-mobile-A',
              'employeeId': 'cashier-1',
              'subtotal': 750.0,
              'totalAmount': 750.0,
              'paymentMethod': 'cash',
              'createdAt': nowA.toIso8601String(),
            },
            'items': [
              {
                'id': 'item-A-1',
                'invoiceId': invIdA,
                'productId': 'prod-coffee',
                'productName': 'Premium Roast Coffee 500g',
                'quantity': 3.0,
                'unitPrice': 250.0,
                'lineTotal': 750.0,
              }
            ]
          }),
          createdAt: nowA,
          updatedAt: nowA,
        ),
      );

      // 4. Simulate offline checkout on Terminal B: 2 tins of Coffee sold
      final nowB = DateTime.now();
      final invIdB = 'inv-termB-001';
      await mobileDbB.into(mobileDbB.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'sync-B-1',
          transactionId: invIdB,
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {
              'id': invIdB,
              'invoiceNumber': 'INV-B-001',
              'deviceId': 'terminal-mobile-B',
              'employeeId': 'cashier-2',
              'subtotal': 500.0,
              'totalAmount': 500.0,
              'paymentMethod': 'upi',
              'createdAt': nowB.toIso8601String(),
            },
            'items': [
              {
                'id': 'item-B-1',
                'invoiceId': invIdB,
                'productId': 'prod-coffee',
                'productName': 'Premium Roast Coffee 500g',
                'quantity': 2.0,
                'unitPrice': 250.0,
                'lineTotal': 500.0,
              }
            ]
          }),
          createdAt: nowB,
          updatedAt: nowB,
        ),
      );

      // 5. Concurrently sync Terminal A and Terminal B workers to Desktop
      final workerA = SyncQueueWorker(database: mobileDbA);
      final workerB = SyncQueueWorker(database: mobileDbB);

      final results = await Future.wait([
        workerA.sync(baseUrl: 'http://127.0.0.1:${server.port}', bearerToken: tokenA),
        workerB.sync(baseUrl: 'http://127.0.0.1:${server.port}', bearerToken: tokenB),
      ]);

      expect(results[0].isSuccess, isTrue);
      expect(results[0].syncedInvoicesCount, equals(1));
      expect(results[1].isSuccess, isTrue);
      expect(results[1].syncedInvoicesCount, equals(1));

      // 6. Verify desktop central inventory: 20.0 - 3.0 - 2.0 = 15.0 exactly!
      final centralProd = await (desktopDb.select(desktopDb.products)..where((tbl) => tbl.id.equals('prod-coffee'))).getSingle();
      expect(centralProd.stockQuantity, equals(15.0));

      // Verify audit log has exactly 2 delta movements (-3.0 and -2.0)
      final history = await desktopDb.getInventoryHistoryForProduct('prod-coffee');
      expect(history.length, equals(2));
      final deltas = history.map((m) => m.deltaQuantity).toList();
      expect(deltas, containsAll([-3.0, -2.0]));

      // Verify both invoices exist on desktop
      final invA = await (desktopDb.select(desktopDb.invoices)..where((tbl) => tbl.id.equals(invIdA))).getSingleOrNull();
      final invB = await (desktopDb.select(desktopDb.invoices)..where((tbl) => tbl.id.equals(invIdB))).getSingleOrNull();
      expect(invA, isNotNull);
      expect(invB, isNotNull);

      // 7. Verify Retry Idempotency: Terminal A retries sync (e.g. simulated network reconnect)
      // Reset terminal A sync queue item to pending to simulate unacknowledged retry
      await (mobileDbA.update(mobileDbA.syncQueue)..where((tbl) => tbl.id.equals('sync-A-1'))).write(
        const SyncQueueCompanion(status: Value('pending')),
      );

      final retryResult = await workerA.sync(baseUrl: 'http://127.0.0.1:${server.port}', bearerToken: tokenA);
      expect(retryResult.isSuccess, isTrue);
      expect(retryResult.syncedInvoicesCount, equals(1));

      // Stock must STILL be 15.0 (NO duplicate decrement!)
      final centralProdAfterRetry = await (desktopDb.select(desktopDb.products)..where((tbl) => tbl.id.equals('prod-coffee'))).getSingle();
      expect(centralProdAfterRetry.stockQuantity, equals(15.0));

      // Still only 2 delta movements
      final historyAfterRetry = await desktopDb.getInventoryHistoryForProduct('prod-coffee');
      expect(historyAfterRetry.length, equals(2));

      // 8. Verify Catalog Propagation:
      // Desktop updates Coffee price to 270.0 and adds Green Tea
      await desktopDb.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-coffee',
          name: 'Premium Roast Coffee 500g',
          sellingPrice: 270.0,
          updatedAt: DateTime.now(),
        ),
      );
      await desktopDb.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-tea',
          name: 'Organic Green Tea 25s',
          sellingPrice: 160.0,
          updatedAt: DateTime.now(),
        ),
      );

      // Mobile B syncs to pull catalog updates
      await workerB.sync(baseUrl: 'http://127.0.0.1:${server.port}', bearerToken: tokenB);

      // Verify Mobile B has updated coffee price and green tea
      final mobileBCoffee = await (mobileDbB.select(mobileDbB.products)..where((tbl) => tbl.id.equals('prod-coffee'))).getSingle();
      expect(mobileBCoffee.sellingPrice, equals(270.0));

      final mobileBTea = await (mobileDbB.select(mobileDbB.products)..where((tbl) => tbl.id.equals('prod-tea'))).getSingle();
      expect(mobileBTea.name, equals('Organic Green Tea 25s'));
      expect(mobileBTea.sellingPrice, equals(160.0));
    });
  });
}

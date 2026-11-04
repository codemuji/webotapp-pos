import 'dart:convert';
import 'package:billing_engine/billing_engine.dart';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase desktopDb;
  late AppDatabase terminal1Db;
  late AppDatabase terminal2Db;
  SyncServer? server;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    desktopDb = AppDatabase.inMemory();
    terminal1Db = AppDatabase.inMemory();
    terminal2Db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await server?.stop();
    await desktopDb.close();
    await terminal1Db.close();
    await terminal2Db.close();
  });

  group('SyncProtocol - Slice 3: End-to-End Offline Resilience & Server Restart Verification', () {
    test('cashiers complete sales while desktop is killed; all pending sales sync cleanly on restart', () async {
      // 1. Setup Central Desktop Node with Catalog
      await desktopDb.upsertCategory(CategoriesCompanion.insert(id: 'cat-fresh', name: 'Fresh Produce'));
      await desktopDb.upsertCategory(CategoriesCompanion.insert(id: 'cat-bakery', name: 'Bakery'));

      await desktopDb.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-apple',
          name: 'Shimla Apples',
          barcode: const Value('890111111111'),
          categoryId: const Value('cat-fresh'),
          sellingPrice: 150.0,
          stockQuantity: const Value(50.0), // 50 kg in central stock
          unit: const Value('kg'),
          updatedAt: DateTime.now(),
        ),
      );

      await desktopDb.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-bread',
          name: 'Multigrain Loaf',
          barcode: const Value('890222222222'),
          categoryId: const Value('cat-bakery'),
          sellingPrice: 45.0,
          stockQuantity: const Value(40.0), // 40 loaves in central stock
          unit: const Value('pkt'),
          updatedAt: DateTime.now(),
        ),
      );

      // Start Desktop Server
      server = SyncServer(database: desktopDb, storeName: 'FreshMart HSR');
      await server!.start(host: '127.0.0.1', port: 0);
      final serverPort = server!.port;

      // 2. Pair Terminal 1 and Terminal 2 while server is online
      final qr = server!.generatePairingQrPayload(host: '127.0.0.1');

      final pairRes1 = await http.post(
        Uri.parse('http://127.0.0.1:$serverPort/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'terminal-01',
          'deviceName': 'Lane 1 Mobile',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final token1 = jsonDecode(pairRes1.body)['bearerToken'] as String;

      final pairRes2 = await http.post(
        Uri.parse('http://127.0.0.1:$serverPort/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'terminal-02',
          'deviceName': 'Lane 2 Mobile',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final token2 = jsonDecode(pairRes2.body)['bearerToken'] as String;

      // Initial catalog pull to both terminals
      final worker1 = SyncQueueWorker(database: terminal1Db);
      final worker2 = SyncQueueWorker(database: terminal2Db);

      await worker1.sync(baseUrl: 'http://127.0.0.1:$serverPort', bearerToken: token1);
      await worker2.sync(baseUrl: 'http://127.0.0.1:$serverPort', bearerToken: token2);

      // Verify both terminals have local catalog
      expect((await terminal1Db.getAllProducts()).length, equals(2));
      expect((await terminal2Db.getAllProducts()).length, equals(2));

      // 3. KILL DESKTOP SERVER (Simulating store power outage / PC crash)
      await server!.stop();
      server = null;

      // 4. CASHIERS SELL OFFLINE ON TERMINALS (100% disconnected)
      // Terminal 1: Sale 1 (3kg apples + 2 loaves bread)
      final now1 = DateTime.now();
      await terminal1Db.recordCheckoutTransaction(
        invoice: InvoicesCompanion.insert(
          id: 'inv-offline-t1-1',
          invoiceNumber: 'INV-T1-001',
          deviceId: 'terminal-01',
          employeeId: 'emp-cashier-1',
          subtotal: 540.0,
          totalAmount: 540.0,
          paymentMethod: 'cash',
          createdAt: now1,
        ),
        items: [
          InvoiceItemsCompanion.insert(
            id: 'item-t1-1-1',
            invoiceId: 'inv-offline-t1-1',
            productId: const Value('prod-apple'),
            productName: 'Shimla Apples',
            quantity: 3.0,
            unitPrice: 150.0,
            lineTotal: 450.0,
          ),
          InvoiceItemsCompanion.insert(
            id: 'item-t1-1-2',
            invoiceId: 'inv-offline-t1-1',
            productId: const Value('prod-bread'),
            productName: 'Multigrain Loaf',
            quantity: 2.0,
            unitPrice: 45.0,
            lineTotal: 90.0,
          ),
        ],
        movements: [
          InventoryMovementsCompanion.insert(
            id: 'mov-t1-1',
            productId: 'prod-apple',
            deltaQuantity: -3.0,
            reason: 'sale',
            referenceId: const Value('inv-offline-t1-1'),
            createdAt: now1,
          ),
          InventoryMovementsCompanion.insert(
            id: 'mov-t1-2',
            productId: 'prod-bread',
            deltaQuantity: -2.0,
            reason: 'sale',
            referenceId: const Value('inv-offline-t1-1'),
            createdAt: now1,
          ),
        ],
        syncQueueItem: SyncQueueCompanion.insert(
          id: 'sq-t1-1',
          transactionId: 'inv-offline-t1-1',
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {
              'id': 'inv-offline-t1-1',
              'invoiceNumber': 'INV-T1-001',
              'deviceId': 'terminal-01',
              'employeeId': 'emp-cashier-1',
              'subtotal': 540.0,
              'totalAmount': 540.0,
              'paymentMethod': 'cash',
              'createdAt': now1.toIso8601String(),
            },
            'items': [
              {
                'id': 'item-t1-1-1',
                'invoiceId': 'inv-offline-t1-1',
                'productId': 'prod-apple',
                'productName': 'Shimla Apples',
                'quantity': 3.0,
                'unitPrice': 150.0,
                'lineTotal': 450.0,
              },
              {
                'id': 'item-t1-1-2',
                'invoiceId': 'inv-offline-t1-1',
                'productId': 'prod-bread',
                'productName': 'Multigrain Loaf',
                'quantity': 2.0,
                'unitPrice': 45.0,
                'lineTotal': 90.0,
              },
            ]
          }),
          createdAt: now1,
          updatedAt: now1,
        ),
      );

      // Terminal 1: Sale 2 (2kg apples + 1 loaf bread)
      final now2 = DateTime.now();
      await terminal1Db.recordCheckoutTransaction(
        invoice: InvoicesCompanion.insert(
          id: 'inv-offline-t1-2',
          invoiceNumber: 'INV-T1-002',
          deviceId: 'terminal-01',
          employeeId: 'emp-cashier-1',
          subtotal: 345.0,
          totalAmount: 345.0,
          paymentMethod: 'cash',
          createdAt: now2,
        ),
        items: [
          InvoiceItemsCompanion.insert(
            id: 'item-t1-2-1',
            invoiceId: 'inv-offline-t1-2',
            productId: const Value('prod-apple'),
            productName: 'Shimla Apples',
            quantity: 2.0,
            unitPrice: 150.0,
            lineTotal: 300.0,
          ),
          InvoiceItemsCompanion.insert(
            id: 'item-t1-2-2',
            invoiceId: 'inv-offline-t1-2',
            productId: const Value('prod-bread'),
            productName: 'Multigrain Loaf',
            quantity: 1.0,
            unitPrice: 45.0,
            lineTotal: 45.0,
          ),
        ],
        movements: [],
        syncQueueItem: SyncQueueCompanion.insert(
          id: 'sq-t1-2',
          transactionId: 'inv-offline-t1-2',
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {
              'id': 'inv-offline-t1-2',
              'invoiceNumber': 'INV-T1-002',
              'deviceId': 'terminal-01',
              'employeeId': 'emp-cashier-1',
              'subtotal': 345.0,
              'totalAmount': 345.0,
              'paymentMethod': 'cash',
              'createdAt': now2.toIso8601String(),
            },
            'items': [
              {
                'id': 'item-t1-2-1',
                'invoiceId': 'inv-offline-t1-2',
                'productId': 'prod-apple',
                'productName': 'Shimla Apples',
                'quantity': 2.0,
                'unitPrice': 150.0,
                'lineTotal': 300.0,
              },
              {
                'id': 'item-t1-2-2',
                'invoiceId': 'inv-offline-t1-2',
                'productId': 'prod-bread',
                'productName': 'Multigrain Loaf',
                'quantity': 1.0,
                'unitPrice': 45.0,
                'lineTotal': 45.0,
              },
            ]
          }),
          createdAt: now2,
          updatedAt: now2,
        ),
      );

      // Terminal 2: Sale 3 (4kg apples + 2 loaves bread)
      final now3 = DateTime.now();
      await terminal2Db.recordCheckoutTransaction(
        invoice: InvoicesCompanion.insert(
          id: 'inv-offline-t2-1',
          invoiceNumber: 'INV-T2-001',
          deviceId: 'terminal-02',
          employeeId: 'emp-cashier-2',
          subtotal: 690.0,
          totalAmount: 690.0,
          paymentMethod: 'upi',
          createdAt: now3,
        ),
        items: [
          InvoiceItemsCompanion.insert(
            id: 'item-t2-1-1',
            invoiceId: 'inv-offline-t2-1',
            productId: const Value('prod-apple'),
            productName: 'Shimla Apples',
            quantity: 4.0,
            unitPrice: 150.0,
            lineTotal: 600.0,
          ),
          InvoiceItemsCompanion.insert(
            id: 'item-t2-1-2',
            invoiceId: 'inv-offline-t2-1',
            productId: const Value('prod-bread'),
            productName: 'Multigrain Loaf',
            quantity: 2.0,
            unitPrice: 45.0,
            lineTotal: 90.0,
          ),
        ],
        movements: [],
        syncQueueItem: SyncQueueCompanion.insert(
          id: 'sq-t2-1',
          transactionId: 'inv-offline-t2-1',
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {
              'id': 'inv-offline-t2-1',
              'invoiceNumber': 'INV-T2-001',
              'deviceId': 'terminal-02',
              'employeeId': 'emp-cashier-2',
              'subtotal': 690.0,
              'totalAmount': 690.0,
              'paymentMethod': 'upi',
              'createdAt': now3.toIso8601String(),
            },
            'items': [
              {
                'id': 'item-t2-1-1',
                'invoiceId': 'inv-offline-t2-1',
                'productId': 'prod-apple',
                'productName': 'Shimla Apples',
                'quantity': 4.0,
                'unitPrice': 150.0,
                'lineTotal': 600.0,
              },
              {
                'id': 'item-t2-1-2',
                'invoiceId': 'inv-offline-t2-1',
                'productId': 'prod-bread',
                'productName': 'Multigrain Loaf',
                'quantity': 2.0,
                'unitPrice': 45.0,
                'lineTotal': 90.0,
              },
            ]
          }),
          createdAt: now3,
          updatedAt: now3,
        ),
      );

      // Verify pending items on terminals while server is down
      expect((await terminal1Db.getPendingSyncItems()).length, equals(2));
      expect((await terminal2Db.getPendingSyncItems()).length, equals(1));

      // Attempting to sync while server is dead fails gracefully without crashes
      final deadSync = await worker1.sync(
        baseUrl: 'http://127.0.0.1:$serverPort',
        bearerToken: token1,
      );
      expect(deadSync.isSuccess, isFalse);
      expect((await terminal1Db.getPendingSyncItems()).length, equals(2)); // items preserved

      // 5. DESKTOP SERVER RESTARTS ON LAN
      server = SyncServer(database: desktopDb, storeName: 'FreshMart HSR');
      await server!.start(host: '127.0.0.1', port: serverPort);

      // 6. TERMINALS RECONNECT AND RECONCILE
      final resSync1 = await worker1.sync(
        baseUrl: 'http://127.0.0.1:$serverPort',
        bearerToken: token1,
      );
      final resSync2 = await worker2.sync(
        baseUrl: 'http://127.0.0.1:$serverPort',
        bearerToken: token2,
      );

      expect(resSync1.isSuccess, isTrue);
      expect(resSync1.syncedInvoicesCount, equals(2));

      expect(resSync2.isSuccess, isTrue);
      expect(resSync2.syncedInvoicesCount, equals(1));

      // All queues drained on both terminals
      expect((await terminal1Db.getPendingSyncItems()), isEmpty);
      expect((await terminal2Db.getPendingSyncItems()), isEmpty);

      // 7. DESKTOP VERIFICATION
      // Total Apples sold: 3kg (T1) + 2kg (T1) + 4kg (T2) = 9kg
      // Initial: 50.0kg -> Reconciled: 41.0kg
      final centralApple = await (desktopDb.select(desktopDb.products)..where((tbl) => tbl.id.equals('prod-apple'))).getSingle();
      expect(centralApple.stockQuantity, equals(41.0));

      // Total Bread sold: 2 loaves (T1) + 1 loaf (T1) + 2 loaves (T2) = 5 loaves
      // Initial: 40.0 -> Reconciled: 35.0
      final centralBread = await (desktopDb.select(desktopDb.products)..where((tbl) => tbl.id.equals('prod-bread'))).getSingle();
      expect(centralBread.stockQuantity, equals(35.0));

      // Total revenue on desktop: 540.0 + 345.0 + 690.0 = 1575.0
      final metrics = await desktopDb.getDashboardMetrics();
      expect(metrics.totalRevenue, equals(1575.0));
      expect(metrics.orderCount, equals(3));
      expect(metrics.paymentBreakdown['cash'], equals(885.0)); // 540 + 345
      expect(metrics.paymentBreakdown['upi'], equals(690.0));
    });
  });
}


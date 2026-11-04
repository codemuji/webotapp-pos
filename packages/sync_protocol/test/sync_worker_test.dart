import 'dart:convert';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncQueueWorker - Slice 3: Mobile Sync Queue Drain & Catalog Pull', () {
    test('successfully pushes pending invoices to desktop server and marks them synced', () async {
      // 1. Seed a pending sync queue item
      final now = DateTime.now();
      final invoiceId = 'inv-worker-1';
      final syncId = 'sync-1';

      final payloadJson = jsonEncode({
        'invoice': {
          'id': invoiceId,
          'invoiceNumber': 'INV-20261104-001',
          'deviceId': 'mobile-term-1',
          'employeeId': 'emp-1',
          'subtotal': 100.0,
          'discount': 0.0,
          'taxAmount': 5.0,
          'totalAmount': 105.0,
          'paymentMethod': 'cash',
          'createdAt': now.toIso8601String(),
        },
        'items': [
          {
            'id': 'item-1',
            'invoiceId': invoiceId,
            'productId': 'prod-bread',
            'productName': 'Whole Wheat Bread',
            'quantity': 1.0,
            'unitPrice': 105.0,
            'lineTotal': 105.0,
          }
        ]
      });

      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: syncId,
          transactionId: invoiceId,
          operation: 'insert_invoice',
          payload: payloadJson,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Verify pending
      final pendingBefore = await db.getPendingSyncItems();
      expect(pendingBefore.length, equals(1));
      expect(pendingBefore.first.status, equals('pending'));

      // 2. Setup mock HTTP client
      final mockClient = MockClient((request) async {
        if (request.url.path == '/sync/invoices') {
          expect(request.headers['Authorization'], equals('Bearer secret-token-xyz'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['invoices'], isNotEmpty);
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'synced': [invoiceId],
              'duplicates': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/sync/catalog') {
          return http.Response(
            jsonEncode({
              'products': [
                {
                  'id': 'prod-butter',
                  'name': 'Amul Salted Butter 500g',
                  'sellingPrice': 275.0,
                  'unit': 'pkt',
                }
              ],
              'categories': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final worker = SyncQueueWorker(
        database: db,
        client: mockClient,
      );

      // 3. Run sync
      final result = await worker.sync(
        baseUrl: 'http://127.0.0.1:8085',
        bearerToken: 'secret-token-xyz',
      );

      // 4. Assertions
      expect(result.syncedInvoicesCount, equals(1));
      expect(result.failedInvoicesCount, equals(0));
      expect(result.catalogUpdatedCount, equals(1));

      // Verify sync item status transitioned to 'synced'
      final pendingAfter = await db.getPendingSyncItems();
      expect(pendingAfter, isEmpty);

      final itemInDb = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(syncId))).getSingle();
      expect(itemInDb.status, equals('synced'));

      // Verify catalog was updated in local mobile DB
      final prod = await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-butter'))).getSingle();
      expect(prod.name, equals('Amul Salted Butter 500g'));
      expect(prod.sellingPrice, equals(275.0));
    });

    test('increments retry count and sets error status when server returns HTTP 500 or network fails', () async {
      final now = DateTime.now();
      final invoiceId = 'inv-fail-1';
      final syncId = 'sync-fail-1';

      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: syncId,
          transactionId: invoiceId,
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {'id': invoiceId, 'totalAmount': 50.0},
            'items': [],
          }),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final worker = SyncQueueWorker(database: db, client: mockClient);

      final result = await worker.sync(
        baseUrl: 'http://127.0.0.1:8085',
        bearerToken: 'any-token',
      );

      expect(result.syncedInvoicesCount, equals(0));
      expect(result.failedInvoicesCount, equals(1));

      final failedItem = await (db.select(db.syncQueue)..where((tbl) => tbl.id.equals(syncId))).getSingle();
      expect(failedItem.status, equals('error'));
      expect(failedItem.retryCount, equals(1));
      expect(failedItem.lastError, contains('500'));
    });

    test('captures catalogError and reports failure when catalog request returns HTTP 401', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/sync/catalog') {
          return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
        }
        return http.Response('Not Found', 404);
      });

      final worker = SyncQueueWorker(database: db, client: mockClient);

      final result = await worker.sync(
        baseUrl: 'http://127.0.0.1:8085',
        bearerToken: 'invalid-or-expired-token',
      );

      expect(result.isSuccess, isFalse);
      expect(result.catalogError, isNotNull);
      expect(result.catalogError, contains('401'));
      expect(result.catalogUpdatedCount, equals(0));
    });

    test('captures catalogError and reports failure when catalog network connection throws', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused (OS Error: Connection refused, errno = 111)');
      });

      final worker = SyncQueueWorker(database: db, client: mockClient);

      final result = await worker.sync(
        baseUrl: 'http://192.168.1.35:8085',
        bearerToken: 'valid-token',
      );

      expect(result.isSuccess, isFalse);
      expect(result.catalogError, isNotNull);
      expect(result.catalogError, contains('Connection refused'));
    });
  });
}


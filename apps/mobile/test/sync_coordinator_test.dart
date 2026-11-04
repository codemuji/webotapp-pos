import 'dart:convert';
import 'package:database/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/src/sync/sync_coordinator.dart';
import 'package:mobile/src/sync/terminal_storage.dart';
import 'package:sync_protocol/sync_protocol.dart';

void main() {
  late AppDatabase db;
  late TerminalStorage storage;

  setUp(() {
    db = AppDatabase.inMemory();
    storage = TerminalStorage.inMemory();
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncCoordinator - Slice 4: Terminal Sync Orchestration', () {
    test('returns notPaired state when terminal has not been paired', () async {
      final coordinator = SyncCoordinator(
        database: db,
        storage: storage,
      );

      final result = await coordinator.runSync();
      expect(result.state, equals(SyncState.notPaired));
      expect(result.message, contains('not paired'));
    });

    test('drains pending sales and pulls catalog when paired and server is reachable', () async {
      // 1. Save pairing credentials
      await storage.saveCredentials(
        bearerToken: 'tok_abc123',
        serverUrl: 'http://192.168.1.50:8085',
        storeName: 'Indiranagar Mart',
        deviceId: 'term-01',
      );

      // 2. Insert pending invoice in sync queue
      final now = DateTime.now();
      await db.into(db.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'sq-1',
          transactionId: 'inv-101',
          operation: 'insert_invoice',
          payload: jsonEncode({
            'invoice': {'id': 'inv-101', 'totalAmount': 150.0},
            'items': [],
          }),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Mock client
      final mockClient = MockClient((request) async {
        if (request.url.path == '/sync/invoices') {
          return http.Response(
            jsonEncode({'status': 'ok', 'synced': ['inv-101'], 'duplicates': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/sync/catalog') {
          return http.Response(
            jsonEncode({
              'products': [
                {'id': 'p1', 'name': 'Tea Leaves', 'sellingPrice': 80.0, 'unit': 'pkt'},
              ],
              'categories': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final coordinator = SyncCoordinator(
        database: db,
        storage: storage,
        worker: SyncQueueWorker(database: db, client: mockClient),
      );

      final pendingCountBefore = await coordinator.getPendingCount();
      expect(pendingCountBefore, equals(1));

      // Act
      final result = await coordinator.runSync();

      // Assert
      expect(result.state, equals(SyncState.success));
      expect(result.syncedCount, equals(1));
      expect(result.catalogUpdatedCount, equals(1));

      final pendingCountAfter = await coordinator.getPendingCount();
      expect(pendingCountAfter, equals(0));
    });
  });
}


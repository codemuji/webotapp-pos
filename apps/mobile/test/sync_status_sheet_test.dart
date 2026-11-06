import 'dart:convert';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/src/sync/sync_coordinator.dart';
import 'package:mobile/src/sync/sync_status_sheet.dart';
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

  group('SyncStatusSheet - Slice 4: Emil Kowalski Offline Sync Modal', () {
    testWidgets('renders sync sheet with paired store info and sync button', (tester) async {
      await storage.saveCredentials(
        bearerToken: 'tok_test',
        serverUrl: 'http://192.168.1.100:8085',
        storeName: 'Indiranagar Supermarket',
        deviceId: 'term-alpha',
      );

      final coordinator = SyncCoordinator(
        database: db,
        storage: storage,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSyncStatusSheet(
                  context: context,
                  coordinator: coordinator,
                  storage: storage,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify header and store title
      expect(find.text('Indiranagar Supermarket'), findsOneWidget);
      expect(find.text('Sync Server Status'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Pair New Server'), findsOneWidget);
    });

    testWidgets('triggers onNavigateToCatalog callback and closes sheet upon successful sync', (tester) async {
      await storage.saveCredentials(
        bearerToken: 'tok_test',
        serverUrl: 'http://192.168.1.100:8085',
        storeName: 'Indiranagar Supermarket',
        deviceId: 'term-alpha',
      );

      final mockClient = MockClient((request) async {
        if (request.url.path == '/sync/invoices') {
          return http.Response(
            jsonEncode({'status': 'ok', 'synced': [], 'duplicates': []}),
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

      bool redirectedToCatalog = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSyncStatusSheet(
                  context: context,
                  coordinator: coordinator,
                  storage: storage,
                  onNavigateToCatalog: () {
                    redirectedToCatalog = true;
                  },
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap Sync Now
      await tester.tap(find.text('Sync Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(redirectedToCatalog, isTrue);
    });
  });
}


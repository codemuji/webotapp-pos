import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/sync/sync_coordinator.dart';
import 'package:mobile/src/sync/sync_status_sheet.dart';
import 'package:mobile/src/sync/terminal_storage.dart';

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
  });
}


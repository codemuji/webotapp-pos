import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop/src/sync/sync_server_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.inMemory();

    // Seed paired device
    await db.upsertDevice(
      DevicesCompanion.insert(
        id: 'term-tab-01',
        deviceName: 'Billing Counter Tablet',
        pairingToken: 'tok_test123',
        isPaired: const Value(true),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncServerScreen - Slice 3: Desktop Embedded Server Manager & QR Pairing Screen', () {
    testWidgets('renders server manager, starts server, and displays pairing QR payload', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SyncServerScreen(
              database: db,
              storeName: 'FreshMart Indiranagar',
              isSimulationMode: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Terminal Pairing & Sync Server'), findsOneWidget);
      expect(find.text('Start Server'), findsOneWidget);
      expect(find.text('Billing Counter Tablet'), findsOneWidget);

      // Tap 'Start Server'
      await tester.tap(find.text('Start Server'));
      await tester.pumpAndSettle();

      // Verify server running status and QR code section
      expect(find.text('Stop Server'), findsOneWidget);
      expect(find.text('Server Active'), findsOneWidget);
      expect(find.text('Scan with Mobile POS Camera'), findsOneWidget);
      expect(find.text('KEY: ABC123XY'), findsOneWidget);

      // Tap 'Stop Server'
      await tester.tap(find.text('Stop Server'));
      await tester.pumpAndSettle();

      expect(find.text('Start Server'), findsOneWidget);
      expect(find.text('Server Offline'), findsOneWidget);
    });
  });
}

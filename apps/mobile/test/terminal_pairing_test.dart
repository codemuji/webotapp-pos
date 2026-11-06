import 'dart:convert';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/src/sync/sync_coordinator.dart';
import 'package:mobile/src/sync/terminal_pairing_screen.dart';
import 'package:mobile/src/sync/terminal_storage.dart';
import 'package:sync_protocol/sync_protocol.dart';

void main() {
  group('TerminalPairing - Slice 4: Mobile Terminal Pairing Scanner & Storage', () {
    test('TerminalStorage stores and retrieves bearer token and server credentials', () async {
      final storage = TerminalStorage.inMemory();

      expect(await storage.isPaired(), isFalse);

      await storage.saveCredentials(
        bearerToken: 'tok_abc123',
        serverUrl: 'http://192.168.1.100:8085',
        storeName: 'FreshMart Whitefield',
        deviceId: 'term-mobile-01',
      );

      expect(await storage.isPaired(), isTrue);
      expect(await storage.getBearerToken(), equals('tok_abc123'));
      expect(await storage.getServerUrl(), equals('http://192.168.1.100:8085'));
      expect(await storage.getStoreName(), equals('FreshMart Whitefield'));
      expect(await storage.getDeviceId(), equals('term-mobile-01'));

      await storage.clear();
      expect(await storage.isPaired(), isFalse);
      expect(await storage.getBearerToken(), isNull);
    });

    testWidgets('TerminalPairingScreen scans pairing QR code, connects, and saves credentials', (tester) async {
      final storage = TerminalStorage.inMemory();

      // Mock pairing client that succeeds
      final mockClient = _MockPairingClient(
        result: const PairingResult.success(
          bearerToken: 'tok_paired_success',
          storeName: 'FreshMart Indiranagar',
          serverUrl: 'http://192.168.1.100:8085',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TerminalPairingScreen(
              storage: storage,
              pairingClient: mockClient,
              isSimulationMode: true,
            ),
          ),
        ),
      );

      expect(find.text('Pair with Admin Node'), findsOneWidget);
      expect(find.text('Scan the QR code displayed on the Windows Desktop Admin dashboard'), findsOneWidget);

      // Simulate scanning pairing QR
      final screenState = tester.state<TerminalPairingScreenState>(find.byType(TerminalPairingScreen));
      const rawQr = '{"protocol":"grocery-pos-sync","version":"1.0","host":"192.168.1.100","port":8085,"pairingSecret":"SEC123","storeName":"FreshMart"}';

      await screenState.handleScannedQr(rawQr);
      await tester.pumpAndSettle();

      // Verify success status
      expect(find.text('Successfully Paired!'), findsOneWidget);
      expect(find.text('FreshMart Indiranagar'), findsOneWidget);

      // Verify token in storage
      expect(await storage.isPaired(), isTrue);
      expect(await storage.getBearerToken(), equals('tok_paired_success'));
    });

    testWidgets('TerminalPairingScreen handles invalid or rejected pairing QR', (tester) async {
      final storage = TerminalStorage.inMemory();

      final mockClient = _MockPairingClient(
        result: const PairingResult.failure('Invalid or expired pairing secret'),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TerminalPairingScreen(
              storage: storage,
              pairingClient: mockClient,
              isSimulationMode: true,
            ),
          ),
        ),
      );

      final screenState = tester.state<TerminalPairingScreenState>(find.byType(TerminalPairingScreen));
      const rawQr = '{"protocol":"grocery-pos-sync","version":"1.0","host":"192.168.1.100","port":8085,"pairingSecret":"BADSEC","storeName":"FreshMart"}';

      await screenState.handleScannedQr(rawQr);
      await tester.pump();

      expect(find.text('Pairing failed: Invalid or expired pairing secret'), findsOneWidget);
      expect(await storage.isPaired(), isFalse);
    });

    testWidgets('TerminalPairingScreen redirects to catalog after successful catalog sync', (tester) async {
      final storage = TerminalStorage.inMemory();
      final db = AppDatabase.inMemory();

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

      final mockPairingClient = _MockPairingClient(
        result: const PairingResult.success(
          bearerToken: 'tok_paired_success',
          storeName: 'FreshMart Indiranagar',
          serverUrl: 'http://192.168.1.100:8085',
        ),
      );

      bool catalogRedirected = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TerminalPairingScreen(
              storage: storage,
              pairingClient: mockPairingClient,
              syncCoordinator: coordinator,
              isSimulationMode: true,
              onNavigateToCatalog: () {
                catalogRedirected = true;
              },
            ),
          ),
        ),
      );

      final screenState = tester.state<TerminalPairingScreenState>(find.byType(TerminalPairingScreen));
      const rawQr = '{"protocol":"grocery-pos-sync","version":"1.0","host":"192.168.1.100","port":8085,"pairingSecret":"SEC123","storeName":"FreshMart"}';

      await screenState.handleScannedQr(rawQr);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 500));

      expect(catalogRedirected, isTrue);
      await db.close();
    });
  });
}

class _MockPairingClient extends PairingClient {
  final PairingResult result;

  _MockPairingClient({required this.result});

  @override
  Future<PairingResult> pair({
    required PairingQrPayload payload,
    required String deviceId,
    required String deviceName,
  }) async {
    return result;
  }
}


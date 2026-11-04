import 'package:database/database.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late SyncServer server;

  setUp(() async {
    db = AppDatabase.inMemory();
    server = SyncServer(
      database: db,
      storeName: 'FreshMart Whitefield',
    );
    await server.start(host: '127.0.0.1', port: 0);
  });

  tearDown(() async {
    await server.stop();
    await db.close();
  });

  group('PairingClient - Slice 2: Mobile Pairing Handshake & Validation', () {
    test('parses raw QR string into PairingQrPayload', () {
      const rawJson = '{"protocol":"grocery-pos-sync","version":"1.0","host":"192.168.1.50","port":8085,"pairingSecret":"sec-9988","storeName":"FreshMart"}';

      final payload = PairingClient.parseQr(rawJson);
      expect(payload, isNotNull);
      expect(payload!.host, equals('192.168.1.50'));
      expect(payload.port, equals(8085));
      expect(payload.pairingSecret, equals('sec-9988'));
      expect(payload.storeName, equals('FreshMart'));
    });

    test('successfully executes pairing handshake and retrieves bearer token', () async {
      final qr = server.generatePairingQrPayload(host: '127.0.0.1');

      final client = PairingClient();
      final result = await client.pair(
        payload: qr,
        deviceId: 'term-tab-01',
        deviceName: 'Cashier Tablet 1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.bearerToken, isNotEmpty);
      expect(result.storeName, equals('FreshMart Whitefield'));
      expect(result.serverUrl, equals('http://127.0.0.1:${server.port}'));
    });

    test('returns failure result when pairing secret is rejected', () async {
      final qr = server.generatePairingQrPayload(host: '127.0.0.1');
      final bogusQr = PairingQrPayload(
        host: qr.host,
        port: qr.port,
        pairingSecret: 'invalid-secret',
        storeName: qr.storeName,
      );

      final client = PairingClient();
      final result = await client.pair(
        payload: bogusQr,
        deviceId: 'term-tab-01',
        deviceName: 'Cashier Tablet 1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid or expired'));
    });
  });
}


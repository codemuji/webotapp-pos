import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('sync_protocol package exports', () {
    test('exports PairingQrPayload and models', () {
      final payload = PairingQrPayload(
        host: '192.168.1.50',
        port: 8080,
        pairingSecret: 'secret-123',
        storeName: 'Main Desktop',
      );
      expect(payload.toRawString(), contains('Main Desktop'));
      expect(payload.baseUrl, equals('http://192.168.1.50:8080'));
    });

    test('exports SyncServer and PairingClient classes', () {
      expect(SyncServer, isNotNull);
      expect(PairingClient, isNotNull);
    });
  });
}

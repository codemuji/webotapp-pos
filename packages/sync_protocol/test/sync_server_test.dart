import 'dart:convert';
import 'package:database/database.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late SyncServer server;

  setUp(() async {
    db = AppDatabase.inMemory();
    server = SyncServer(
      database: db,
      storeName: 'FreshMart Indiranagar',
    );
    await server.start(host: '127.0.0.1', port: 0); // Port 0 binds to any free ephemeral port
  });

  tearDown(() async {
    await server.stop();
    await db.close();
  });

  group('SyncServer - Slice 1: Embedded Shelf HTTP Server & Pairing Flow', () {
    test('GET /health returns 200 with server status and store metadata', () async {
      final res = await http.get(Uri.parse('http://127.0.0.1:${server.port}/health'));
      expect(res.statusCode, equals(200));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      expect(data['status'], equals('ok'));
      expect(data['storeName'], equals('FreshMart Indiranagar'));
    });

    test('POST /pair with valid pairing secret registers mobile device and returns bearer token', () async {
      // 1. Generate pairing secret on server
      final qrPayload = server.generatePairingQrPayload(host: '192.168.1.100');
      expect(qrPayload.pairingSecret, isNotEmpty);
      expect(qrPayload.host, equals('192.168.1.100'));
      expect(qrPayload.port, equals(server.port));

      // 2. Mobile sends pairing handshake
      final pairBody = jsonEncode({
        'deviceId': 'mobile-term-01',
        'deviceName': 'Samsung POS Tablet',
        'pairingSecret': qrPayload.pairingSecret,
      });

      final res = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: pairBody,
      );

      expect(res.statusCode, equals(200));
      final pairData = jsonDecode(res.body) as Map<String, dynamic>;
      expect(pairData['bearerToken'], isNotEmpty);
      expect(pairData['storeName'], equals('FreshMart Indiranagar'));

      // 3. Verify device registered in SQLite
      final registeredDevice = await db.getDeviceByToken(pairData['bearerToken']);
      expect(registeredDevice, isNotNull);
      expect(registeredDevice!.id, equals('mobile-term-01'));
      expect(registeredDevice.deviceName, equals('Samsung POS Tablet'));
      expect(registeredDevice.isPaired, isTrue);
    });

    test('POST /pair rejects request with invalid pairing secret', () async {
      server.generatePairingQrPayload(host: '127.0.0.1');

      final pairBody = jsonEncode({
        'deviceId': 'rogue-device',
        'deviceName': 'Unknown Phone',
        'pairingSecret': 'wrong-secret-1234',
      });

      final res = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: pairBody,
      );

      expect(res.statusCode, equals(401));
    });

    test('protected endpoint GET /sync/catalog rejects unauthenticated requests', () async {
      final res = await http.get(Uri.parse('http://127.0.0.1:${server.port}/sync/catalog'));
      expect(res.statusCode, equals(401));
    });

    test('protected endpoint GET /sync/catalog succeeds with valid bearer token', () async {
      // Pair device
      final qr = server.generatePairingQrPayload(host: '127.0.0.1');
      final pairRes = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'term-02',
          'deviceName': 'Pixel POS',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final token = jsonDecode(pairRes.body)['bearerToken'] as String;

      // Seed catalog in database
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-bread',
              name: 'Brown Bread',
              sellingPrice: 40.0,
              updatedAt: DateTime.now(),
            ),
          );

      // Request catalog with Bearer token
      final res = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/sync/catalog'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(res.statusCode, equals(200));
      final catalog = jsonDecode(res.body) as Map<String, dynamic>;
      final products = catalog['products'] as List;
      expect(products.length, equals(1));
      expect(products.first['name'], equals('Brown Bread'));
    });
  });
}


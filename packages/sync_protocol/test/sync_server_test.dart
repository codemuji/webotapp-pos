import 'dart:convert';
import 'package:database/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

    test('POST /sync/invoices rejects unauthenticated requests', () async {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/sync/invoices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'invoices': []}),
      );
      expect(res.statusCode, equals(401));
    });

    test('POST /sync/invoices ingests invoices idempotently and updates delta inventory', () async {
      // 1. Pair device to obtain bearer token
      final qr = server.generatePairingQrPayload(host: '127.0.0.1');
      final pairRes = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': 'term-sync-01',
          'deviceName': 'Checkout Terminal 1',
          'pairingSecret': qr.pairingSecret,
        }),
      );
      final token = jsonDecode(pairRes.body)['bearerToken'] as String;

      // 2. Seed catalog with 50 units of Rice
      await db.upsertProduct(
        ProductsCompanion.insert(
          id: 'prod-rice',
          name: 'Basmati Rice 1kg',
          barcode: const Value('890123456789'),
          sellingPrice: 120.0,
          stockQuantity: const Value(50.0),
          unit: const Value('kg'),
          updatedAt: DateTime.now(),
        ),
      );

      // 3. Prepare invoices payload
      final invoicesPayload = {
        'invoices': [
          {
            'invoice': {
              'id': 'inv-remote-001',
              'invoiceNumber': 'INV-20261104-101',
              'deviceId': 'term-sync-01',
              'employeeId': 'emp-cashier-1',
              'subtotal': 240.0,
              'discount': 0.0,
              'taxAmount': 0.0,
              'totalAmount': 240.0,
              'paymentMethod': 'cash',
              'createdAt': DateTime.now().toIso8601String(),
            },
            'items': [
              {
                'id': 'item-remote-001-1',
                'invoiceId': 'inv-remote-001',
                'productId': 'prod-rice',
                'productName': 'Basmati Rice 1kg',
                'barcode': '890123456789',
                'quantity': 2.0,
                'unitPrice': 120.0,
                'lineTotal': 240.0,
              }
            ]
          }
        ]
      };

      // 4. Send POST /sync/invoices
      final res1 = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/sync/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(invoicesPayload),
      );

      expect(res1.statusCode, equals(200));
      final data1 = jsonDecode(res1.body) as Map<String, dynamic>;
      expect(data1['status'], equals('ok'));
      expect(data1['synced'], contains('inv-remote-001'));
      expect(data1['duplicates'], isEmpty);

      // Verify stock was reduced from 50 to 48
      final prodAfterFirst = await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-rice'))).getSingle();
      expect(prodAfterFirst.stockQuantity, equals(48.0));

      // 5. Send identical payload again (retry/idempotency test)
      final res2 = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/sync/invoices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(invoicesPayload),
      );

      expect(res2.statusCode, equals(200));
      final data2 = jsonDecode(res2.body) as Map<String, dynamic>;
      expect(data2['status'], equals('ok'));
      expect(data2['synced'], contains('inv-remote-001'));
      expect(data2['duplicates'], contains('inv-remote-001'));

      // Verify stock remains 48 (NOT decremented again!)
      final prodAfterSecond = await (db.select(db.products)..where((tbl) => tbl.id.equals('prod-rice'))).getSingle();
      expect(prodAfterSecond.stockQuantity, equals(48.0));
    });
  });
}


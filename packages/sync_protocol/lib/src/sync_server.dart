import 'dart:convert';
import 'dart:io';
import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'pairing_models.dart';

/// Embedded Shelf HTTP Server for Windows Desktop node.
/// Manages terminal QR pairing, local network discovery, and offline sync protocol.
class SyncServer {
  final AppDatabase database;
  final String storeName;
  final Uuid _uuid = const Uuid();

  HttpServer? _server;
  String? _activePairingSecret;

  SyncServer({
    required this.database,
    required this.storeName,
  });

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// Generates a fresh ephemeral pairing secret and QR code payload.
  PairingQrPayload generatePairingQrPayload({required String host}) {
    final secret = _uuid.v4().substring(0, 8);
    _activePairingSecret = secret;

    return PairingQrPayload(
      host: host,
      port: port,
      pairingSecret: secret,
      storeName: storeName,
    );
  }

  /// Starts the embedded Shelf server on the given host and port.
  Future<void> start({dynamic host = '0.0.0.0', int port = 8085}) async {
    if (_server != null) return;

    final router = Router();

    // 1. Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'storeName': storeName,
          'version': '1.0.0',
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // 2. Terminal pairing endpoint
    router.post('/pair', (Request request) async {
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      final deviceId = body['deviceId'] as String?;
      final deviceName = body['deviceName'] as String?;
      final pairingSecret = body['pairingSecret'] as String?;

      if (deviceId == null || pairingSecret == null) {
        return Response(HttpStatus.badRequest, body: jsonEncode({'error': 'Missing deviceId or pairingSecret'}));
      }

      if (_activePairingSecret == null || pairingSecret != _activePairingSecret) {
        return Response(HttpStatus.unauthorized, body: jsonEncode({'error': 'Invalid or expired pairing secret'}));
      }

      // Generate bearer token and register device in Drift SQLite
      final bearerToken = 'tok_${_uuid.v4()}';

      await database.upsertDevice(
        DevicesCompanion.insert(
          id: deviceId,
          deviceName: deviceName ?? 'Mobile Terminal',
          pairingToken: bearerToken,
          isPaired: const Value(true),
          lastSyncedAt: Value(DateTime.now()),
        ),
      );

      return Response.ok(
        jsonEncode({
          'bearerToken': bearerToken,
          'deviceId': deviceId,
          'storeName': storeName,
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // 3. Catalog sync endpoint (authenticated)
    router.get('/sync/catalog', (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(HttpStatus.unauthorized, body: jsonEncode({'error': 'Missing Bearer token'}));
      }

      final token = authHeader.substring(7).trim();
      final device = await database.getDeviceByToken(token);
      if (device == null) {
        return Response(HttpStatus.unauthorized, body: jsonEncode({'error': 'Invalid device token'}));
      }

      final products = await database.getActiveProducts();
      final categories = await database.getAllCategories();

      return Response.ok(
        jsonEncode({
          'products': products
              .map((p) => {
                    'id': p.id,
                    'name': p.name,
                    'barcode': p.barcode,
                    'sku': p.sku,
                    'categoryId': p.categoryId,
                    'sellingPrice': p.sellingPrice,
                    'unit': p.unit,
                  })
              .toList(),
          'categories': categories
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'description': c.description,
                  })
              .toList(),
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    _server = await shelf_io.serve(handler, host, port);
  }

  /// Stops the running Shelf server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _activePairingSecret = null;
  }
}

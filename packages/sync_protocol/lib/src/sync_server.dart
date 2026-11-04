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
    Future<Response> handleCatalogSync(Request request) async {
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
    }

    router.get('/sync/catalog', handleCatalogSync);
    router.get('/api/v1/sync/catalog', handleCatalogSync);

    // 4. Invoices sync ingestion endpoint (authenticated)
    Future<Response> handleInvoiceIngestion(Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(HttpStatus.unauthorized, body: jsonEncode({'error': 'Missing Bearer token'}));
      }

      final token = authHeader.substring(7).trim();
      final device = await database.getDeviceByToken(token);
      if (device == null) {
        return Response(HttpStatus.unauthorized, body: jsonEncode({'error': 'Invalid device token'}));
      }

      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final invoicesList = body['invoices'] as List? ?? [];

      final syncedIds = <String>[];
      final duplicateIds = <String>[];

      for (final invObj in invoicesList) {
        final invMap = invObj['invoice'] as Map<String, dynamic>;
        final itemsList = invObj['items'] as List? ?? [];

        final invoiceId = invMap['id'] as String;
        final invoiceCompanion = InvoicesCompanion.insert(
          id: invoiceId,
          invoiceNumber: invMap['invoiceNumber'] as String? ?? 'INV-$invoiceId',
          deviceId: invMap['deviceId'] as String? ?? device.id,
          employeeId: invMap['employeeId'] as String? ?? 'default',
          customerId: Value(invMap['customerId'] as String?),
          subtotal: (invMap['subtotal'] as num).toDouble(),
          discount: Value((invMap['discount'] as num?)?.toDouble() ?? 0.0),
          taxAmount: Value((invMap['taxAmount'] as num?)?.toDouble() ?? 0.0),
          totalAmount: (invMap['totalAmount'] as num).toDouble(),
          paymentMethod: invMap['paymentMethod'] as String? ?? 'cash',
          createdAt: DateTime.tryParse(invMap['createdAt'] as String? ?? '') ?? DateTime.now(),
          syncStatus: const Value('synced'),
        );

        final itemCompanions = <InvoiceItemsCompanion>[];
        for (int i = 0; i < itemsList.length; i++) {
          final itm = itemsList[i] as Map<String, dynamic>;
          final itemId = itm['id'] as String? ?? 'item-$invoiceId-$i';
          itemCompanions.add(
            InvoiceItemsCompanion.insert(
              id: itemId,
              invoiceId: invoiceId,
              productId: Value(itm['productId'] as String?),
              productName: itm['productName'] as String? ?? 'Item',
              barcode: Value(itm['barcode'] as String?),
              quantity: (itm['quantity'] as num).toDouble(),
              unitPrice: (itm['unitPrice'] as num).toDouble(),
              discount: Value((itm['discount'] as num?)?.toDouble() ?? 0.0),
              taxAmount: Value((itm['taxAmount'] as num?)?.toDouble() ?? 0.0),
              lineTotal: (itm['lineTotal'] as num).toDouble(),
            ),
          );
        }

        final result = await database.ingestSyncedInvoice(
          invoice: invoiceCompanion,
          items: itemCompanions,
        );

        syncedIds.add(invoiceId);
        if (result.isDuplicate) {
          duplicateIds.add(invoiceId);
        }
      }

      await database.updateDeviceSyncTime(device.id, DateTime.now());

      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'synced': syncedIds,
          'duplicates': duplicateIds,
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    router.post('/sync/invoices', handleInvoiceIngestion);
    router.post('/api/v1/sync/invoices', handleInvoiceIngestion);

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

import 'dart:convert';
import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

/// Summary result of a sync execution run.
class SyncWorkerResult {
  final int syncedInvoicesCount;
  final int failedInvoicesCount;
  final int catalogUpdatedCount;
  final String? catalogError;
  final String? networkError;

  const SyncWorkerResult({
    required this.syncedInvoicesCount,
    required this.failedInvoicesCount,
    required this.catalogUpdatedCount,
    this.catalogError,
    this.networkError,
  });

  bool get isSuccess =>
      failedInvoicesCount == 0 && catalogError == null && networkError == null;
}

/// Mobile background / manual worker that pushes pending sync queue items to the desktop
/// and pulls the latest product catalog & categories.
class SyncQueueWorker {
  final AppDatabase database;
  final http.Client client;

  SyncQueueWorker({
    required this.database,
    http.Client? client,
  }) : client = client ?? http.Client();

  /// Executes full sync:
  /// 1. Pushes pending local transactions (invoices & line items) to desktop server.
  /// 2. Pulls updated product catalog and saves changes locally.
  Future<SyncWorkerResult> sync({
    required String baseUrl,
    required String bearerToken,
  }) async {
    List<SyncQueueData> pendingItems = [];
    try {
      pendingItems = await database.getPendingSyncItems();
    } catch (e) {
      return SyncWorkerResult(
        syncedInvoicesCount: 0,
        failedInvoicesCount: 0,
        catalogUpdatedCount: 0,
        networkError: 'Local database error: $e',
        catalogError: 'Local database error: $e',
      );
    }
    int syncedCount = 0;
    int failedCount = 0;
    int catalogUpdatedCount = 0;
    String? networkError;
    String? catalogError;

    // 1. Drain pending sync queue
    if (pendingItems.isNotEmpty) {
      final invoicesBatch = <Map<String, dynamic>>[];
      final itemMap = <String, SyncQueueData>{};

      for (final item in pendingItems) {
        try {
          final payload = jsonDecode(item.payload) as Map<String, dynamic>;
          invoicesBatch.add(payload);
          final inv = payload['invoice'] as Map<String, dynamic>?;
          if (inv != null && inv['id'] != null) {
            itemMap[inv['id'] as String] = item;
          }
        } catch (e) {
          await database.recordSyncItemFailure(item.id, 'Invalid JSON payload: $e');
          failedCount++;
        }
      }

      if (invoicesBatch.isNotEmpty) {
        try {
          final response = await client.post(
            Uri.parse('$baseUrl/sync/invoices'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $bearerToken',
            },
            body: jsonEncode({'invoices': invoicesBatch}),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final syncedIds = (data['synced'] as List? ?? []).cast<String>();

            for (final invId in syncedIds) {
              final queueItem = itemMap[invId];
              if (queueItem != null) {
                await database.markSyncItemSuccess(queueItem.id);
                syncedCount++;
              }
            }
          } else {
            final error = 'Server error HTTP ${response.statusCode}: ${response.body}';
            networkError = error;
            for (final item in pendingItems) {
              await database.recordSyncItemFailure(item.id, error);
              failedCount++;
            }
          }
        } catch (e) {
          final error = 'Network failure: $e';
          networkError = error;
          for (final item in pendingItems) {
            await database.recordSyncItemFailure(item.id, error);
            failedCount++;
          }
        }
      }
    }

    // 2. Pull updated catalog from desktop
    try {
      final catalogResponse = await client.get(
        Uri.parse('$baseUrl/sync/catalog'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (catalogResponse.statusCode == 200) {
        final catalogData = jsonDecode(catalogResponse.body) as Map<String, dynamic>;
        final products = catalogData['products'] as List? ?? [];
        final categories = catalogData['categories'] as List? ?? [];

        for (final cat in categories) {
          await database.upsertCategory(
            CategoriesCompanion.insert(
              id: cat['id'] as String,
              name: cat['name'] as String,
              description: Value(cat['description'] as String?),
              defaultTaxRate: Value((cat['defaultTaxRate'] as num?)?.toDouble() ?? 0.0),
              defaultHsnCode: Value(cat['defaultHsnCode'] as String?),
            ),
          );
        }

        for (final prod in products) {
          await database.upsertProduct(
            ProductsCompanion.insert(
              id: prod['id'] as String,
              name: prod['name'] as String,
              barcode: Value(prod['barcode'] as String?),
              secondaryBarcode: Value(prod['secondaryBarcode'] as String?),
              sku: Value(prod['sku'] as String?),
              categoryId: Value(prod['categoryId'] as String?),
              sellingPrice: (prod['sellingPrice'] as num).toDouble(),
              purchasePrice: Value((prod['purchasePrice'] as num?)?.toDouble()),
              stockQuantity: Value((prod['stockQuantity'] as num?)?.toDouble() ?? 0.0),
              unit: Value(prod['unit'] as String? ?? 'pcs'),
              parentProductId: Value(prod['parentProductId'] as String?),
              variantName: Value(prod['variantName'] as String?),
              taxRate: Value((prod['taxRate'] as num?)?.toDouble() ?? 0.0),
              hsnCode: Value(prod['hsnCode'] as String?),
              minStockAlert: Value((prod['minStockAlert'] as num?)?.toDouble() ?? 5.0),
              updatedAt: DateTime.now(),
            ),
          );
          catalogUpdatedCount++;
        }
      } else if (catalogResponse.statusCode == 401) {
        catalogError = 'Terminal unauthorized (HTTP 401). Please re-pair with desktop node.';
      } else {
        catalogError = 'Server error fetching catalog: HTTP ${catalogResponse.statusCode}';
      }
    } catch (e) {
      catalogError = 'Unable to reach desktop node at $baseUrl ($e). Check Wi-Fi connection and ensure Desktop App is running.';
    }

    return SyncWorkerResult(
      syncedInvoicesCount: syncedCount,
      failedInvoicesCount: failedCount,
      catalogUpdatedCount: catalogUpdatedCount,
      catalogError: catalogError,
      networkError: networkError,
    );
  }
}


import 'dart:convert';
import 'package:database/database.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

/// Summary result of a sync execution run.
class SyncWorkerResult {
  final int syncedInvoicesCount;
  final int failedInvoicesCount;
  final int catalogUpdatedCount;

  const SyncWorkerResult({
    required this.syncedInvoicesCount,
    required this.failedInvoicesCount,
    required this.catalogUpdatedCount,
  });

  bool get isSuccess => failedInvoicesCount == 0;
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
    final pendingItems = await database.getPendingSyncItems();
    int syncedCount = 0;
    int failedCount = 0;
    int catalogUpdatedCount = 0;

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
          );

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
            for (final item in pendingItems) {
              await database.recordSyncItemFailure(item.id, error);
              failedCount++;
            }
          }
        } catch (e) {
          final error = 'Network failure: $e';
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
      );

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
            ),
          );
        }

        for (final prod in products) {
          await database.upsertProduct(
            ProductsCompanion.insert(
              id: prod['id'] as String,
              name: prod['name'] as String,
              barcode: Value(prod['barcode'] as String?),
              sku: Value(prod['sku'] as String?),
              categoryId: Value(prod['categoryId'] as String?),
              sellingPrice: (prod['sellingPrice'] as num).toDouble(),
              unit: Value(prod['unit'] as String? ?? 'pcs'),
              updatedAt: DateTime.now(),
            ),
          );
          catalogUpdatedCount++;
        }
      }
    } catch (_) {
      // Catalog pull error is non-fatal if offline
    }

    return SyncWorkerResult(
      syncedInvoicesCount: syncedCount,
      failedInvoicesCount: failedCount,
      catalogUpdatedCount: catalogUpdatedCount,
    );
  }
}


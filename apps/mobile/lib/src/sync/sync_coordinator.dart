import 'package:database/database.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart';
import 'terminal_storage.dart';

enum SyncState { idle, syncing, success, failure, notPaired }

class SyncCoordinatorResult {
  final SyncState state;
  final String message;
  final int syncedCount;
  final int failedCount;
  final int catalogUpdatedCount;

  const SyncCoordinatorResult({
    required this.state,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.catalogUpdatedCount = 0,
  });
}

class SyncCoordinator {
  final AppDatabase database;
  final TerminalStorage storage;
  final SyncQueueWorker worker;

  SyncCoordinator({
    required this.database,
    required this.storage,
    SyncQueueWorker? worker,
    http.Client? client,
  }) : worker = worker ?? SyncQueueWorker(database: database, client: client);

  Future<int> getPendingCount() async {
    try {
      final pending = await database.getPendingSyncItems();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  Future<SyncCoordinatorResult> runSync() async {
    try {
      final isPaired = await storage.isPaired();
      if (!isPaired) {
        return const SyncCoordinatorResult(
          state: SyncState.notPaired,
          message: 'Terminal not paired with desktop server.',
        );
      }

      final token = await storage.getBearerToken();
      final url = await storage.getServerUrl();

      if (token == null || url == null) {
        return const SyncCoordinatorResult(
          state: SyncState.notPaired,
          message: 'Missing server credentials.',
        );
      }

      final result = await worker.sync(
        baseUrl: url,
        bearerToken: token,
      );

      if (result.catalogError != null && result.syncedInvoicesCount == 0 && result.failedInvoicesCount == 0) {
        return SyncCoordinatorResult(
          state: SyncState.failure,
          message: result.catalogError!,
          syncedCount: result.syncedInvoicesCount,
          failedCount: result.failedInvoicesCount,
          catalogUpdatedCount: result.catalogUpdatedCount,
        );
      }

      if (result.failedInvoicesCount > 0 && result.syncedInvoicesCount == 0) {
        return SyncCoordinatorResult(
          state: SyncState.failure,
          message: result.networkError ?? 'Sync failed for ${result.failedInvoicesCount} sale(s).',
          syncedCount: result.syncedInvoicesCount,
          failedCount: result.failedInvoicesCount,
          catalogUpdatedCount: result.catalogUpdatedCount,
        );
      }

      final message = 'Synced ${result.syncedInvoicesCount} sale(s), updated ${result.catalogUpdatedCount} catalog items.';
      return SyncCoordinatorResult(
        state: SyncState.success,
        message: message,
        syncedCount: result.syncedInvoicesCount,
        failedCount: result.failedInvoicesCount,
        catalogUpdatedCount: result.catalogUpdatedCount,
      );
    } catch (e) {
      return SyncCoordinatorResult(
        state: SyncState.failure,
        message: 'Sync error: $e',
      );
    }
  }
}


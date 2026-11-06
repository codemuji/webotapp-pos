import 'package:database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'sync/sync_coordinator.dart';
import 'sync/terminal_storage.dart';

/// Global singleton provider for the local Drift SQLite database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});

final terminalStorageProvider = Provider<TerminalStorage>((ref) {
  return const TerminalStorage();
});

final pairingClientProvider = Provider<PairingClient>((ref) {
  return PairingClient();
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(terminalStorageProvider);
  return SyncCoordinator(database: db, storage: storage);
});

/// Tab index provider for mobile navigation: 0 = Counter POS / Cart, 1 = Catalog
final mobileTabIndexProvider = StateProvider<int>((ref) => 0);

/// Catalog revision counter bumped whenever a sync or catalog mutation finishes.
final catalogRevisionProvider = StateProvider<int>((ref) => 0);



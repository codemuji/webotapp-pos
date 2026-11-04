import 'package:database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sync_protocol/sync_protocol.dart';
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


import 'package:database/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global singleton provider for the local Drift SQLite database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.inMemory();
  ref.onDispose(() => db.close());
  return db;
});


import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'database.dart';

/// Metadata describing a local SQLite backup file.
class BackupFileMetadata {
  final String filePath;
  final String fileName;
  final int sizeInBytes;
  final DateTime createdAt;

  const BackupFileMetadata({
    required this.filePath,
    required this.fileName,
    required this.sizeInBytes,
    required this.createdAt,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Integrity verification result of a prospective backup file.
class BackupValidationResult {
  final bool isValid;
  final int tableCount;
  final List<String> tablesFound;
  final String? errorMessage;

  const BackupValidationResult({
    required this.isValid,
    this.tableCount = 0,
    this.tablesFound = const [],
    this.errorMessage,
  });
}

/// Manages atomic SQLite backups via VACUUM INTO, backup validation, and restoration.
class BackupManager {
  const BackupManager();

  /// Creates a consistent, defragmented backup of the active SQLite database
  /// into [destinationDir] using SQLite's native `VACUUM INTO` statement.
  Future<BackupFileMetadata> createBackup({
    required AppDatabase database,
    required String destinationDir,
    String? fileName,
  }) async {
    final dir = Directory(destinationDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final now = DateTime.now();
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final targetName = fileName ?? 'grocery_pos_backup_${datePart}_$timePart.db';
    final targetPath = p.join(destinationDir, targetName);

    // If destination file already exists, remove it first because VACUUM INTO fails if file exists
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    // Windows SQLite VACUUM INTO expects forward slashes
    final normalizedPath = targetPath.replaceAll(r'\', '/');
    await database.customStatement("VACUUM INTO '$normalizedPath';");

    final file = File(targetPath);
    final size = await file.length();

    return BackupFileMetadata(
      filePath: targetPath,
      fileName: targetName,
      sizeInBytes: size,
      createdAt: now,
    );
  }

  /// Verifies SQLite schema and integrity of a backup file before restoration.
  Future<BackupValidationResult> validateBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Backup file does not exist.',
      );
    }

    Database? db;
    try {
      db = sqlite3.open(filePath);

      // 1. Run integrity check
      final integrityRows = db.select('PRAGMA integrity_check;');
      if (integrityRows.isEmpty || integrityRows.first.values.first != 'ok') {
        return BackupValidationResult(
          isValid: false,
          errorMessage: 'PRAGMA integrity_check failed: ${integrityRows.firstOrNull?.values.firstOrNull}',
        );
      }

      // 2. Verify expected POS tables exist
      final tableRows = db.select("SELECT name FROM sqlite_master WHERE type='table';");
      final tables = tableRows.map((r) => r['name'] as String).toList();

      const requiredTables = ['products', 'categories', 'invoices'];
      final missingTables = requiredTables.where((t) => !tables.contains(t)).toList();

      if (missingTables.isNotEmpty) {
        return BackupValidationResult(
          isValid: false,
          tableCount: tables.length,
          tablesFound: tables,
          errorMessage: 'Missing required schema tables: ${missingTables.join(', ')}',
        );
      }

      return BackupValidationResult(
        isValid: true,
        tableCount: tables.length,
        tablesFound: tables,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Failed to inspect backup database: $e',
      );
    } finally {
      db?.dispose();
    }
  }

  /// Restores verified backup file to [targetDbPath].
  Future<bool> restoreBackup({
    required String backupFilePath,
    required String targetDbPath,
  }) async {
    final validation = await validateBackup(backupFilePath);
    if (!validation.isValid) {
      throw StateError('Cannot restore invalid backup: ${validation.errorMessage}');
    }

    final targetFile = File(targetDbPath);
    if (await targetFile.exists()) {
      final backupSafetyPath = '$targetDbPath.bak';
      await targetFile.copy(backupSafetyPath);
    }

    await File(backupFilePath).copy(targetDbPath);
    return true;
  }

  /// Scans [destinationDir] for existing backup files, returning them sorted descending by timestamp.
  Future<List<BackupFileMetadata>> listBackups(String destinationDir) async {
    final dir = Directory(destinationDir);
    if (!await dir.exists()) {
      return [];
    }

    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('grocery_pos_backup_') && name.endsWith('.db');
    }).toList();

    final metadataList = <BackupFileMetadata>[];
    for (final file in files) {
      final name = p.basename(file.path);
      final size = file.lengthSync();
      final stat = file.statSync();

      metadataList.add(
        BackupFileMetadata(
          filePath: file.path,
          fileName: name,
          sizeInBytes: size,
          createdAt: stat.modified,
        ),
      );
    }

    metadataList.sort((a, b) => b.fileName.compareTo(a.fileName));
    return metadataList;
  }
}


import 'dart:io';
import 'package:database/database.dart';
import 'package:database/src/backup_manager.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late AppDatabase db;
  late BackupManager backupManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grocery_pos_backup_test_');
    dbPath = p.join(tempDir.path, 'grocery_pos.db');
    db = AppDatabase(NativeDatabase(File(dbPath)));
    backupManager = const BackupManager();

    // Seed some data into db
    await db.upsertCategory(CategoriesCompanion.insert(id: 'c1', name: 'Snacks'));
    await db.upsertProduct(
      ProductsCompanion.insert(
        id: 'p1',
        name: 'Potato Chips',
        barcode: const Value('1234567890'),
        sellingPrice: 30.0,
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupManager - Slice 1: SQLite Backup, Integrity Validation & Restore', () {
    test('creates consistent SQLite backup file via VACUUM INTO', () async {
      final backupDir = p.join(tempDir.path, 'backups');
      await Directory(backupDir).create();

      final metadata = await backupManager.createBackup(
        database: db,
        destinationDir: backupDir,
      );

      expect(metadata.fileName, startsWith('grocery_pos_backup_'));
      expect(metadata.fileName, endsWith('.db'));
      expect(File(metadata.filePath).existsSync(), isTrue);
      expect(metadata.sizeInBytes, greaterThan(0));
    });

    test('validates backup file schema integrity and detects corrupt or non-POS files', () async {
      final backupDir = p.join(tempDir.path, 'backups');
      await Directory(backupDir).create();

      final metadata = await backupManager.createBackup(
        database: db,
        destinationDir: backupDir,
      );

      // Validate valid backup
      final validResult = await backupManager.validateBackup(metadata.filePath);
      expect(validResult.isValid, isTrue);
      expect(validResult.tablesFound, containsAll(['products', 'categories', 'invoices']));

      // Validate corrupt/fake file
      final fakeFile = File(p.join(tempDir.path, 'fake_backup.db'));
      await fakeFile.writeAsString('This is not a sqlite database!');

      final fakeResult = await backupManager.validateBackup(fakeFile.path);
      expect(fakeResult.isValid, isFalse);
      expect(fakeResult.errorMessage, isNotNull);
    });

    test('lists existing backups in directory ordered descending by date', () async {
      final backupDir = p.join(tempDir.path, 'backups_list');
      await Directory(backupDir).create();

      await backupManager.createBackup(
        database: db,
        destinationDir: backupDir,
        fileName: 'grocery_pos_backup_20261101_100000.db',
      );
      await backupManager.createBackup(
        database: db,
        destinationDir: backupDir,
        fileName: 'grocery_pos_backup_20261102_100000.db',
      );

      final backups = await backupManager.listBackups(backupDir);
      expect(backups.length, equals(2));
      expect(backups.first.fileName, equals('grocery_pos_backup_20261102_100000.db'));
    });

    test('restores verified backup to target database file', () async {
      final backupDir = p.join(tempDir.path, 'backups_restore');
      await Directory(backupDir).create();

      final metadata = await backupManager.createBackup(
        database: db,
        destinationDir: backupDir,
      );
      await db.close();

      // Corrupt original db file
      await File(dbPath).writeAsString('corrupted db');

      // Restore from backup
      final success = await backupManager.restoreBackup(
        backupFilePath: metadata.filePath,
        targetDbPath: dbPath,
      );
      expect(success, isTrue);

      // Reopen restored database and verify data integrity
      final restoredDb = AppDatabase(NativeDatabase(File(dbPath)));
      final products = await restoredDb.getAllProducts();
      expect(products.length, equals(1));
      expect(products.first.name, equals('Potato Chips'));
      await restoredDb.close();
    });
  });
}

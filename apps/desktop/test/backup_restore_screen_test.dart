import 'dart:io';
import 'package:database/database.dart';
import 'package:desktop/src/backup/backup_restore_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late String dbPath;
  late AppDatabase db;
  late String backupDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('desktop_backup_test_');
    dbPath = p.join(tempDir.path, 'grocery_pos.db');
    backupDir = p.join(tempDir.path, 'backups');
    await Directory(backupDir).create();

    db = AppDatabase(NativeDatabase(File(dbPath)));
    await db.upsertCategory(CategoriesCompanion.insert(id: 'c1', name: 'Bakery'));
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupRestoreScreen - Slice 2: Desktop Admin Backup & Restore Management UI', () {
    testWidgets('renders backup manager, creates backup, and displays in history list', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupRestoreScreen(
              database: db,
              backupDirectory: backupDir,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      // Verify header and UI elements
      expect(find.text('Database Backup & Restore'), findsOneWidget);
      expect(find.text('Create Local Backup'), findsOneWidget);
      expect(find.text('Export to USB Drive'), findsOneWidget);

      // Tap Create Local Backup
      await tester.runAsync(() async {
        await tester.tap(find.text('Create Local Backup'));
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify success banner and history item
      expect(find.textContaining('Backup created successfully'), findsOneWidget);
      expect(find.textContaining('grocery_pos_backup_'), findsNWidgets(2));
      expect(find.text('Validate'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });
  });
}

import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Desktop administrative screen for database snapshots, USB export, integrity checking, and recovery.
class BackupRestoreScreen extends StatefulWidget {
  final AppDatabase database;
  final String? backupDirectory;
  final String? targetDbPath;
  final List<BackupFileMetadata>? initialBackups;
  final bool isSimulationMode;

  const BackupRestoreScreen({
    super.key,
    required this.database,
    this.backupDirectory,
    this.targetDbPath,
    this.initialBackups,
    this.isSimulationMode = false,
  });

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupManager = const BackupManager();
  late String _backupDir;
  List<BackupFileMetadata> _backups = [];
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccessStatus = true;
  bool _autoBackupEnabled = true;

  @override
  void initState() {
    super.initState();
    _backupDir = widget.backupDirectory ?? p.join(Directory.current.path, 'backups');
    if (widget.initialBackups != null) {
      _backups = widget.initialBackups!;
      _isLoading = false;
    } else if (!widget.isSimulationMode) {
      _loadBackups();
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final list = await _backupManager.listBackups(_backupDir);
    if (mounted) {
      setState(() {
        _backups = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final metadata = await _backupManager.createBackup(
        database: widget.database,
        destinationDir: _backupDir,
      );

      await _loadBackups();
      if (mounted) {
        setState(() {
          _statusMessage = 'Backup created successfully: ${metadata.fileName} (${metadata.formattedSize})';
          _isSuccessStatus = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Backup creation failed: $e';
          _isSuccessStatus = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExportToUsb() async {
    final usbController = TextEditingController(text: r'E:\GroceryPOS_Backups');
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Backup to USB Storage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter destination folder on external USB flash drive:'),
            const SizedBox(height: 12),
            TextField(
              controller: usbController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.usb_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, usbController.text),
            child: const Text('Export Now'),
          ),
        ],
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _statusMessage = null;
      });

      try {
        final metadata = await _backupManager.createBackup(
          database: widget.database,
          destinationDir: selected,
        );
        if (mounted) {
          setState(() {
            _statusMessage = 'USB Export completed: ${metadata.filePath}';
            _isSuccessStatus = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'USB Export failed: $e';
            _isSuccessStatus = false;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _handleValidateBackup(BackupFileMetadata backup) async {
    final result = await _backupManager.validateBackup(backup.filePath);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
              color: result.isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
            const SizedBox(width: 8),
            Text(result.isValid ? 'Integrity Check Passed' : 'Integrity Check Failed'),
          ],
        ),
        content: Text(
          result.isValid
              ? 'Backup file "${backup.fileName}" is completely valid.\nVerified ${result.tableCount} schema tables: ${result.tablesFound.join(", ")}.'
              : 'Backup corruption detected: ${result.errorMessage}',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _handleRestoreBackup(BackupFileMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Database Restoration'),
        content: Text(
          'Warning: Restoring "${backup.fileName}" will overwrite the active SQLite database.\n'
          'A safety rollback copy (.bak) will automatically be preserved.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Database'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.targetDbPath != null) {
      try {
        await _backupManager.restoreBackup(
          backupFilePath: backup.filePath,
          targetDbPath: widget.targetDbPath!,
        );
        if (mounted) {
          setState(() {
            _statusMessage = 'Database restored successfully from ${backup.fileName}';
            _isSuccessStatus = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Database restore failed: $e';
            _isSuccessStatus = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database Backup & Restore',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create local snapshots, export to USB storage, and restore databases with schema validation.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleExportToUsb,
                    icon: const Icon(Icons.usb_rounded, size: 18),
                    label: const Text('Export to USB Drive'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _handleCreateBackup,
                    icon: const Icon(Icons.backup_rounded, size: 18),
                    label: const Text('Create Local Backup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status Banner
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isSuccessStatus ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSuccessStatus ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccessStatus ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    color: _isSuccessStatus ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isSuccessStatus ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Scheduler & Directory Settings Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open_rounded, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Backup Directory: $_backupDir',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Automated Daily Backups (23:00)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _autoBackupEnabled,
                      activeColor: const Color(0xFF16A34A),
                      onChanged: (val) => setState(() => _autoBackupEnabled = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Backups Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _backups.isEmpty
                      ? const Center(
                          child: Text(
                            'No backups found in directory. Click "Create Local Backup" to start.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _backups.length,
                          separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          itemBuilder: (ctx, idx) {
                            final b = _backups[idx];
                            return Row(
                              children: [
                                const Icon(Icons.storage_rounded, color: Color(0xFF64748B), size: 28),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.fileName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Size: ${b.formattedSize}  •  Created: ${b.createdAt.toLocal().toString().split(".")[0]}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _handleValidateBackup(b),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Validate'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: () => _handleRestoreBackup(b),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Restore'),
                                ),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

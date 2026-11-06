import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../widgets/tactile_button.dart';
import 'sync_coordinator.dart';
import 'terminal_storage.dart';

/// Displays the offline synchronization status sheet implementing Emil Kowalski
/// micro-interaction patterns: tactile buttons, clear typography, and fixed metric heights.
Future<void> showSyncStatusSheet({
  required BuildContext context,
  required SyncCoordinator coordinator,
  required TerminalStorage storage,
  VoidCallback? onPairNewServer,
  VoidCallback? onNavigateToCatalog,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SyncStatusSheetContent(
      coordinator: coordinator,
      storage: storage,
      onPairNewServer: onPairNewServer,
      onNavigateToCatalog: onNavigateToCatalog,
    ),
  );
}

class _SyncStatusSheetContent extends StatefulWidget {
  final SyncCoordinator coordinator;
  final TerminalStorage storage;
  final VoidCallback? onPairNewServer;
  final VoidCallback? onNavigateToCatalog;

  const _SyncStatusSheetContent({
    required this.coordinator,
    required this.storage,
    this.onPairNewServer,
    this.onNavigateToCatalog,
  });

  @override
  State<_SyncStatusSheetContent> createState() => _SyncStatusSheetContentState();
}

class _SyncStatusSheetContentState extends State<_SyncStatusSheetContent> {
  bool _isLoading = false;
  String? _storeName;
  String? _serverUrl;
  bool _isPaired = false;
  int _pendingCount = 0;
  int _localCatalogCount = 0;
  String? _feedbackMessage;
  bool _isFeedbackSuccess = true;
  bool _isTesting = false;
  String? _testMessage;
  bool _isTestSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final paired = await widget.storage.isPaired().catchError((_) => false);
    final name = await widget.storage.getStoreName().catchError((_) => null);
    final url = await widget.storage.getServerUrl().catchError((_) => null);
    int pending = 0;
    int prodCount = 0;
    try {
      pending = await widget.coordinator.getPendingCount();
      final prods = await widget.coordinator.database.getActiveProducts();
      prodCount = prods.length;
    } catch (e) {
      debugPrint('Error loading db items in sheet: $e');
    }

    if (mounted) {
      setState(() {
        _isPaired = paired;
        _storeName = name ?? (paired ? 'Connected Store' : 'Unpaired Terminal');
        _serverUrl = url ?? 'Not Connected';
        _pendingCount = pending;
        _localCatalogCount = prodCount;
      });
    }
  }

  Future<void> _handleTestConnection() async {
    if (_serverUrl == null || _serverUrl == 'Not Connected') return;
    HapticFeedback.lightImpact();
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      final client = http.Client();
      final res = await client.get(Uri.parse('$_serverUrl/health')).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isTesting = false;
          _isTestSuccess = res.statusCode == 200;
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            _testMessage = 'Online: Connected to "${data['storeName'] ?? 'Desktop'}"';
          } else {
            _testMessage = 'Server responded with HTTP ${res.statusCode}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _isTestSuccess = false;
          _testMessage = 'Unreachable ($_serverUrl). Ensure laptop is on same Wi-Fi.';
        });
      }
    }
  }

  Future<void> _handleSyncNow() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      final result = await widget.coordinator.runSync();
      int newPending = 0;
      int prodCount = 0;
      try {
        newPending = await widget.coordinator.getPendingCount();
        final prods = await widget.coordinator.database.getActiveProducts();
        prodCount = prods.length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _pendingCount = newPending;
          _localCatalogCount = prodCount;
          _feedbackMessage = result.message;
          _isFeedbackSuccess = result.state == SyncState.success;
        });

        if (result.state == SyncState.success && widget.onNavigateToCatalog != null) {
          final messenger = ScaffoldMessenger.of(context);
          if (mounted) {
            Navigator.of(context).pop();
            widget.onNavigateToCatalog!();
            messenger.showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _feedbackMessage = 'Sync error: $e';
          _isFeedbackSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync Server Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _storeName ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isPaired ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isPaired ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPaired ? 'PAIRED' : 'UNPAIRED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _isPaired ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Server details & Pending count card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Desktop Node:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _serverUrl ?? '-',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (_isPaired && _serverUrl != null && _serverUrl != 'Not Connected') ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _isTesting ? null : _handleTestConnection,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: _isTesting
                                    ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                                    : const Text('Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isTestSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _testMessage!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isTestSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                    ),
                  ),
                ],
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Catalog Products Cached:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _localCatalogCount > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_localCatalogCount item${_localCatalogCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _localCatalogCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pending Offline Sales:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _pendingCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_pendingCount queued',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_feedbackMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isFeedbackSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFeedbackSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Text(
                _feedbackMessage!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isFeedbackSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          TactileButton(
            onPressed: _isLoading ? null : _handleSyncNow,
            minHeight: 52,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sync Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          TactileButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onPairNewServer != null) {
                widget.onPairNewServer!();
              }
            },
            minHeight: 46,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Pair New Server',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


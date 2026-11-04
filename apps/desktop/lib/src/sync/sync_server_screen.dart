import 'dart:io';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sync_protocol/sync_protocol.dart';

/// Embedded Shelf HTTP Server control panel and Terminal QR pairing screen.
class SyncServerScreen extends StatefulWidget {
  final AppDatabase database;
  final String storeName;
  final bool isSimulationMode;
  final SyncServer? server;

  const SyncServerScreen({
    super.key,
    required this.database,
    this.storeName = 'FreshMart Store',
    this.isSimulationMode = false,
    this.server,
  });

  @override
  State<SyncServerScreen> createState() => SyncServerScreenState();
}

class SyncServerScreenState extends State<SyncServerScreen> {
  late final SyncServer _server;
  PairingQrPayload? _qrPayload;
  List<Device> _devices = [];
  bool _isSimulatedRunning = false;

  @override
  void initState() {
    super.initState();
    _server = widget.server ??
        SyncServer(
          database: widget.database,
          storeName: widget.storeName,
        );
    _loadDevices();
    _initQrIfRunning();
  }

  Future<void> _initQrIfRunning() async {
    if (!widget.isSimulationMode && _server.isRunning) {
      final ip = await _detectLocalIp();
      final qr = _server.generatePairingQrPayload(host: ip);
      if (mounted) {
        setState(() {
          _qrPayload = qr;
        });
      }
    }
  }

  @override
  void dispose() {
    if (!widget.isSimulationMode && widget.server == null) {
      _server.stop();
    }
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final list = await widget.database.getAllDevices();
    if (mounted) {
      setState(() {
        _devices = list;
      });
    }
  }

  Future<String> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (!name.contains('wsl') && !name.contains('virtual') && !name.contains('vethernet')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.1.35';
  }

  /// Toggles server status between running and stopped.
  Future<void> toggleServer() async {
    if (widget.isSimulationMode) {
      setState(() {
        _isSimulatedRunning = !_isSimulatedRunning;
        if (_isSimulatedRunning) {
          _qrPayload = PairingQrPayload(
            host: '192.168.1.100',
            port: 8085,
            pairingSecret: 'ABC123XY',
            storeName: widget.storeName,
          );
        } else {
          _qrPayload = null;
        }
      });
      return;
    }

    try {
      if (_server.isRunning) {
        await _server.stop();
        if (mounted) {
          setState(() {
            _qrPayload = null;
          });
        }
      } else {
        await _server.start(host: InternetAddress.anyIPv4, port: 8085);
        final ip = await _detectLocalIp();
        final qr = _server.generatePairingQrPayload(host: ip);
        if (mounted) {
          setState(() {
            _qrPayload = qr;
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling server: $e');
    }
  }

  bool get isRunning => widget.isSimulationMode ? _isSimulatedRunning : _server.isRunning;
  int get activePort => widget.isSimulationMode ? 8085 : _server.port;

  @override
  Widget build(BuildContext context) {
    final active = isRunning;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        'Terminal Pairing & Sync Server',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Embedded local Shelf daemon for terminal discovery, pairing, and transaction sync',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  key: const Key('btn_toggle_server'),
                  onPressed: toggleServer,
                  icon: Icon(active ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(active ? 'Stop Server' : 'Start Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Server Status Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active ? 'Server Active' : 'Server Offline',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active
                                ? 'Listening on port $activePort (LAN IP: ${_qrPayload?.host ?? "0.0.0.0"})'
                                : 'Start server to allow mobile cashiers to connect',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic QR Code Section when server is running
            if (active && _qrPayload != null) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Real Scannable QR Code and Pairing Key
                    Column(
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: QrImageView(
                            data: _qrPayload!.toRawString(),
                            version: QrVersions.auto,
                            size: 164.0,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'KEY: ${_qrPayload!.pairingSecret}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan with Mobile POS Camera',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Open the Mobile POS app on your Android terminal, navigate to Settings > Pair Server, and scan this QR code to establish secure mutual authentication.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildInfoPill('HOST', _qrPayload!.host),
                              const SizedBox(width: 12),
                              _buildInfoPill('PORT', '${_qrPayload!.port}'),
                              const SizedBox(width: 12),
                              _buildInfoPill('SECRET', _qrPayload!.pairingSecret),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Paired Terminals Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Paired Terminals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  tooltip: 'Refresh connected terminals',
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: _loadDevices,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _devices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(28.0),
                        child: Center(
                          child: Text('No mobile terminals paired yet', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) {
                          final d = _devices[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEFF6FF),
                              child: Icon(Icons.tablet_android_rounded, color: Color(0xFF3B82F6), size: 20),
                            ),
                            title: Text(d.deviceName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Device ID: ${d.id}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text('Paired', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

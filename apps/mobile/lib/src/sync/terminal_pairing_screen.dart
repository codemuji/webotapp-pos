import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sync_protocol/sync_protocol.dart';
import '../widgets/tactile_button.dart';
import 'sync_coordinator.dart';
import 'terminal_storage.dart';

/// Screen allowing a mobile POS terminal to scan the Admin Desktop QR code,
/// perform mutual pairing handshake, and store bearer authentication credentials.
class TerminalPairingScreen extends StatefulWidget {
  final TerminalStorage storage;
  final PairingClient pairingClient;
  final bool isSimulationMode;
  final SyncCoordinator? syncCoordinator;

  const TerminalPairingScreen({
    super.key,
    required this.storage,
    required this.pairingClient,
    this.isSimulationMode = false,
    this.syncCoordinator,
  });

  @override
  State<TerminalPairingScreen> createState() => TerminalPairingScreenState();
}

class TerminalPairingScreenState extends State<TerminalPairingScreen> {
  late final MobileScannerController? _scannerController;
  bool _isProcessing = false;
  String? _pairedStoreName;
  String? _pairedServerUrl;
  bool _isTestingConnection = false;
  String? _testConnectionResult;
  bool _isTestSuccess = false;
  bool _isCatalogSyncing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSimulationMode) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
      );
    } else {
      _scannerController = null;
    }
    _checkExistingPairing();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPairing() async {
    final paired = await widget.storage.isPaired();
    if (paired) {
      final name = await widget.storage.getStoreName();
      final url = await widget.storage.getServerUrl();
      if (mounted) {
        setState(() {
          _pairedStoreName = name ?? 'Store Admin Node';
          _pairedServerUrl = url;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (_pairedServerUrl == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isTestingConnection = true;
      _testConnectionResult = null;
    });

    final isOk = await widget.pairingClient.ping(_pairedServerUrl!);
    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _isTestSuccess = isOk;
        _testConnectionResult = isOk
            ? 'Server reachable! Connected on $_pairedServerUrl'
            : 'Cannot reach $_pairedServerUrl. Ensure laptop is on same Wi-Fi and Desktop POS is running.';
      });
    }
  }

  /// Processes raw QR data captured from camera or simulation
  Future<void> handleScannedQr(String rawQr) async {
    if (_isProcessing) return;

    final payload = PairingClient.parseQr(rawQr);
    if (payload == null) {
      _showError('Invalid pairing QR code format');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await widget.pairingClient.pair(
        payload: payload,
        deviceId: 'term-mobile-01',
        deviceName: 'Android Mobile Terminal',
      );

      if (!mounted) return;

      if (result.isSuccess) {
        await widget.storage.saveCredentials(
          bearerToken: result.bearerToken!,
          serverUrl: result.serverUrl!,
          storeName: result.storeName!,
          deviceId: 'term-mobile-01',
        );

        if (widget.syncCoordinator != null) {
          try {
            await widget.syncCoordinator!.runSync();
          } catch (_) {}
        }

        setState(() {
          _pairedStoreName = result.storeName;
          _pairedServerUrl = result.serverUrl;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        String msg = result.errorMessage ?? 'Pairing rejected';
        if (msg.contains('TimeoutException')) {
          msg = 'Connection timed out reaching ${payload.host}:${payload.port}.\n\n'
              '1. Connect phone to Wi-Fi: Ensure phone is on Wi-Fi (not 5G/mobile data).\n'
              '2. Same Wi-Fi: Phone and laptop must be on the same router.\n'
              '3. Windows Firewall: Run allow_firewall_sync_port.bat as Admin on laptop.';
        }
        _showError('Pairing failed: $msg');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        String msg = e.toString();
        if (msg.contains('TimeoutException')) {
          msg = 'Connection timed out reaching ${payload.host}:${payload.port}.\n\n'
              '1. Connect phone to Wi-Fi: Ensure phone is on Wi-Fi (not 5G/mobile data).\n'
              '2. Same Wi-Fi: Phone and laptop must be on the same router.\n'
              '3. Windows Firewall: Run allow_firewall_sync_port.bat as Admin on laptop.';
        }
        _showError('Connection error:\n$msg');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showManualPairDialog() {
    final ipController = TextEditingController(text: '192.168.1.35');
    final portController = TextEditingController(text: '8085');
    final secretController = TextEditingController();
    bool isTesting = false;
    String? pingResult;
    bool isPingSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Manual Terminal Pairing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter the connection details displayed on the Windows Desktop Admin screen:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Desktop Server IP',
                  hintText: 'e.g. 192.168.1.35',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '8085',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretController,
                decoration: const InputDecoration(
                  labelText: 'Pairing Key / Secret',
                  hintText: 'e.g. ABC123XY',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Ping Test Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isTesting
                          ? null
                          : () async {
                              final ip = ipController.text.trim();
                              final port = portController.text.trim();
                              if (ip.isEmpty) return;
                              setModalState(() {
                                isTesting = true;
                                pingResult = null;
                              });
                              final targetUrl = 'http://$ip:$port';
                              final ok = await widget.pairingClient.ping(targetUrl);
                              setModalState(() {
                                isTesting = false;
                                isPingSuccess = ok;
                                pingResult = ok
                                    ? 'Success: Desktop reachable on $targetUrl'
                                    : 'Failed: Cannot reach $targetUrl within timeout';
                              });
                            },
                      icon: isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering, size: 16),
                      label: const Text('Test Connection (Ping)'),
                    ),
                  ),
                ],
              ),
              if (pingResult != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPingSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isPingSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    pingResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPingSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TactileButton(
                onPressed: () {
                  final ip = ipController.text.trim();
                  final port = int.tryParse(portController.text.trim()) ?? 8085;
                  final secret = secretController.text.trim();
                  if (ip.isEmpty) {
                    _showError('Please enter Desktop IP address');
                    return;
                  }
                  if (secret.isEmpty) {
                    _showError('Please enter the 8-character pairing key from desktop');
                    return;
                  }
                  Navigator.pop(ctx);
                  final payload = PairingQrPayload(
                    host: ip,
                    port: port,
                    pairingSecret: secret,
                    storeName: 'WebotApp Store',
                  );
                  handleScannedQr(payload.toRawString());
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Connect & Pair',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unpairTerminal() async {
    await widget.storage.clear();
    setState(() {
      _pairedStoreName = null;
      _pairedServerUrl = null;
      _testConnectionResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pairedStoreName != null) {
      return _buildPairedView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Viewfinder
          if (!widget.isSimulationMode && _scannerController != null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    handleScannedQr(raw);
                    break;
                  }
                }
              },
            )
          else
            Container(
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 64,
                  color: Color(0xFF334155),
                ),
              ),
            ),

          // Reticle Targeting HUD
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF10B981), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Instructions overlay
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  children: [
                    TactileButton(
                      onPressed: () => Navigator.of(context).pop(),
                      minWidth: 44,
                      minHeight: 44,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pair with Admin Node',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Scan the QR code displayed on the Windows Desktop Admin dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        '📶 Phone & laptop must be on the same Wi-Fi (turn off 5G data)',
                        style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar (Torch & Manual Pairing options)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!widget.isSimulationMode && _scannerController != null) ...[
                  TactileButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    minWidth: 48,
                    minHeight: 48,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                TactileButton(
                  onPressed: _showManualPairDialog,
                  minHeight: 48,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, color: Color(0xFF0F172A), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Enter Manually',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPairedView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Terminal Pairing Status', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 64, color: Color(0xFF10B981)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Successfully Paired!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                _pairedStoreName ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              if (_pairedServerUrl != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    _pairedServerUrl!,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
              if (_testConnectionResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isTestSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isTestSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _testConnectionResult!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isTestSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Test Connection Button
              if (_pairedServerUrl != null) ...[
                TactileButton(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  minHeight: 44,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isTestingConnection)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
                        else
                          const Icon(Icons.network_check_rounded, color: Color(0xFF0F172A), size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Test Server Connection',
                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.syncCoordinator != null) ...[
                TactileButton(
                  onPressed: _isCatalogSyncing
                      ? null
                      : () async {
                          setState(() => _isCatalogSyncing = true);
                          try {
                            final res = await widget.syncCoordinator!.runSync();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.state == SyncState.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync error: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isCatalogSyncing = false);
                            }
                          }
                        },
                  minHeight: 48,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isCatalogSyncing)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isCatalogSyncing ? 'Syncing...' : 'Sync Catalog Now',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TactileButton(
                onPressed: _showManualPairDialog,
                minHeight: 44,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF475569), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Edit IP / Re-pair Manually',
                        style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TactileButton(
                onPressed: _unpairTerminal,
                minHeight: 48,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Unpair Terminal',
                        style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


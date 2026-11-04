import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sync_protocol/sync_protocol.dart';
import '../widgets/tactile_button.dart';
import 'terminal_storage.dart';

/// Screen allowing a mobile POS terminal to scan the Admin Desktop QR code,
/// perform mutual pairing handshake, and store bearer authentication credentials.
class TerminalPairingScreen extends StatefulWidget {
  final TerminalStorage storage;
  final PairingClient pairingClient;
  final bool isSimulationMode;

  const TerminalPairingScreen({
    super.key,
    required this.storage,
    required this.pairingClient,
    this.isSimulationMode = false,
  });

  @override
  State<TerminalPairingScreen> createState() => TerminalPairingScreenState();
}

class TerminalPairingScreenState extends State<TerminalPairingScreen> {
  late final MobileScannerController? _scannerController;
  bool _isProcessing = false;
  String? _pairedStoreName;

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
      if (mounted) {
        setState(() {
          _pairedStoreName = name ?? 'Store Admin Node';
        });
      }
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

        setState(() {
          _pairedStoreName = result.storeName;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        _showError('Pairing failed: ${result.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Connection error: $e');
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const SizedBox(height: 20),
            TactileButton(
              onPressed: () {
                final ip = ipController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 8085;
                final secret = secretController.text.trim();
                if (ip.isEmpty || secret.isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final payload = PairingQrPayload(
                  host: ip,
                  port: port,
                  pairingSecret: secret,
                  storeName: 'FreshMart Store',
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
    );
  }

  Future<void> _unpairTerminal() async {
    await widget.storage.clear();
    setState(() {
      _pairedStoreName = null;
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
                  child: const Text(
                    'Scan the QR code displayed on the Windows Desktop Admin dashboard',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
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
              const SizedBox(height: 36),
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


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
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
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
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  handleScannedQr(raw);
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


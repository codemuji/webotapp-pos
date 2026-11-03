import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../cart/cart_state.dart';
import '../widgets/tactile_button.dart';
import 'barcode_scan_handler.dart';
import 'manual_search_sheet.dart';

/// Full-screen high-performance camera scanner for barcode and QR code detection.
/// Features camera reticle HUD, torch toggle, manual search modal trigger,
/// and live floating cart badge for continuous multi-item scanning.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final AppDatabase database;
  final bool isSimulationMode;

  const BarcodeScannerScreen({
    super.key,
    required this.database,
    this.isSimulationMode = false,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => BarcodeScannerScreenState();
}

class BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController? _scannerController;
  late final BarcodeScanHandler _scanHandler;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scanHandler = BarcodeScanHandler(
      database: widget.database,
      cartNotifier: ref.read(cartProvider.notifier),
    );

    if (!widget.isSimulationMode) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } else {
      _scannerController = null;
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  /// Process an incoming raw barcode string from camera or simulation
  Future<void> handleBarcode(String rawBarcode) async {
    final result = await _scanHandler.onBarcodeScanned(rawBarcode);

    if (!mounted) return;

    if (result.status == ScanStatus.notFound) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode $rawBarcode not found in catalog'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _scannerController?.toggleTorch();
  }

  void _openManualSearch() {
    showManualProductSearchSheet(
      context: context,
      database: widget.database,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Viewfinder or Simulated Background
          if (!widget.isSimulationMode && _scannerController != null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull?.rawValue;
                if (barcode != null && barcode.isNotEmpty) {
                  handleBarcode(barcode);
                }
              },
            )
          else
            Container(
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
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
                border: Border.all(
                  color: const Color(0xFF38BDF8),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Scan guidance caption
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.2,
            child: const Center(
              child: Text(
                'Point camera at barcode or QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top action bar
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Row(
                  children: [
                    TactileButton(
                      onPressed: _toggleTorch,
                      minWidth: 44,
                      minHeight: 44,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isTorchOn ? Icons.flash_off_outlined : Icons.flash_on_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TactileButton(
                      onPressed: _openManualSearch,
                      minWidth: 44,
                      minHeight: 44,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Floating Bottom Cart Bar
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: SafeArea(
              child: TactileButton(
                onPressed: () => Navigator.of(context).pop(),
                minHeight: 56,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            cart.items.isEmpty
                                ? '0 items in cart'
                                : '${cart.items.length} items • ₹${cart.netPayable.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text(
                            'View Cart',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

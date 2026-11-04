import 'dart:async';
import 'package:database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../cart/cart_state.dart';
import '../sync/sync_coordinator.dart';
import '../widgets/tactile_button.dart';
import 'barcode_scan_handler.dart';
import 'manual_search_sheet.dart';

/// Full-screen high-performance camera scanner for barcode and QR code detection.
/// Features camera reticle HUD, torch toggle, live scanning feedback banner,
/// manual barcode entry fallback, and floating cart badge.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final AppDatabase database;
  final bool isSimulationMode;
  final SyncCoordinator? syncCoordinator;

  const BarcodeScannerScreen({
    super.key,
    required this.database,
    this.isSimulationMode = false,
    this.syncCoordinator,
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => BarcodeScannerScreenState();
}

class BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController? _scannerController;
  late final BarcodeScanHandler _scanHandler;
  bool _isTorchOn = false;
  int _localProductCount = 0;
  bool _isSyncing = false;
  String? _scanFeedbackMessage;
  bool _isFeedbackSuccess = true;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _scanHandler = BarcodeScanHandler(
      database: widget.database,
      cartNotifier: ref.read(cartProvider.notifier),
    );

    if (!widget.isSimulationMode) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        formats: const [BarcodeFormat.all],
      );
    } else {
      _scannerController = null;
    }

    _refreshCatalogCount();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _refreshCatalogCount() async {
    final prods = await widget.database.getAllProducts();
    if (mounted) {
      setState(() => _localProductCount = prods.length);
    }
  }

  Future<void> _handleSyncCatalog() async {
    if (widget.syncCoordinator == null || _isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final res = await widget.syncCoordinator!.runSync();
      await _refreshCatalogCount();
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _scanFeedbackMessage = res.message;
          _isFeedbackSuccess = res.state == SyncState.success;
        });
        _scheduleFeedbackDismiss();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _scanFeedbackMessage = 'Sync failed: $e';
          _isFeedbackSuccess = false;
        });
        _scheduleFeedbackDismiss();
      }
    }
  }

  void _scheduleFeedbackDismiss() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _scanFeedbackMessage = null);
    });
  }

  /// Process an incoming raw barcode string from camera, simulation, or manual entry
  Future<void> handleBarcode(String rawBarcode) async {
    final cleanBarcode = rawBarcode.trim();
    if (cleanBarcode.isEmpty) return;

    final result = await _scanHandler.onBarcodeScanned(cleanBarcode);
    if (!mounted) return;

    if (result.status == ScanStatus.found) {
      setState(() {
        _scanFeedbackMessage = '✓ Added ${result.product!.name} (₹${result.product!.sellingPrice.toStringAsFixed(2)})';
        _isFeedbackSuccess = true;
      });
      _scheduleFeedbackDismiss();
    } else if (result.status == ScanStatus.notFound) {
      setState(() {
        _scanFeedbackMessage = '⚠️ Barcode "$cleanBarcode" not found in catalog';
        _isFeedbackSuccess = false;
      });
      _scheduleFeedbackDismiss();

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

  void _showManualBarcodeInput() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type barcode number printed below the lines:'),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. 890103000001',
                prefixIcon: Icon(Icons.qr_code_rounded),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx);
                handleBarcode(val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                handleBarcode(val);
              }
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
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
                for (final b in capture.barcodes) {
                  final raw = b.rawValue ?? b.displayValue;
                  if (raw != null && raw.trim().isNotEmpty) {
                    handleBarcode(raw);
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
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: Color(0xFF334155),
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

          // Live Scan Feedback Banner (above reticle)
          if (_scanFeedbackMessage != null)
            Positioned(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).size.height * 0.28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _isFeedbackSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Text(
                  _scanFeedbackMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Empty catalog warning pill if local catalog has 0 products
          if (_localProductCount == 0)
            Positioned(
              left: 20,
              right: 20,
              top: 105,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Local catalog empty (0 items).',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ),
                    if (widget.syncCoordinator != null)
                      TextButton(
                        onPressed: _isSyncing ? null : _handleSyncCatalog,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _isSyncing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                  ],
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
                      onPressed: _showManualBarcodeInput,
                      minWidth: 44,
                      minHeight: 44,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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

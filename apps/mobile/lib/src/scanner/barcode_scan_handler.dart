import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import '../cart/cart_state.dart';
import 'scanner_beep_service.dart';

/// Status of a barcode scan attempt.
enum ScanStatus { found, notFound, debounced }

/// Outcome of processing a scanned barcode.
class ScanResult {
  final ScanStatus status;
  final String rawBarcode;
  final Product? product;

  const ScanResult({
    required this.status,
    required this.rawBarcode,
    this.product,
  });

  const ScanResult.found(this.product, this.rawBarcode) : status = ScanStatus.found;
  const ScanResult.notFound(this.rawBarcode)
      : status = ScanStatus.notFound,
        product = null;
  const ScanResult.debounced(this.rawBarcode)
      : status = ScanStatus.debounced,
        product = null;
}

/// Coordinates real-time barcode processing: SQLite lookup, optimistic cart addition,
/// scanner gun audio beep + haptic feedback triggering, and rapid duplicate video frame debouncing.
class BarcodeScanHandler {
  final AppDatabase database;
  final CartNotifier cartNotifier;
  final VoidCallback? onHapticFeedback;
  final Duration debounceDuration;
  final Duration differentBarcodeDebounce;

  String? _lastBarcode;
  DateTime? _lastScanTime;
  bool _isProcessing = false;

  BarcodeScanHandler({
    required this.database,
    required this.cartNotifier,
    this.onHapticFeedback,
    this.debounceDuration = const Duration(milliseconds: 1800),
    this.differentBarcodeDebounce = const Duration(milliseconds: 400),
  });

  /// Processes a raw barcode detected by camera or hardware scanner.
  Future<ScanResult> onBarcodeScanned(String rawBarcode) async {
    final now = DateTime.now();

    // 1. Drop concurrent in-flight frame executions immediately
    if (_isProcessing) {
      return ScanResult.debounced(rawBarcode);
    }

    // 2. Cooldown check: prevent duplicate scans when camera lingers over barcode
    if (_lastScanTime != null) {
      final elapsed = now.difference(_lastScanTime!);
      if (_lastBarcode == rawBarcode && elapsed < debounceDuration) {
        return ScanResult.debounced(rawBarcode);
      }
      if (_lastBarcode != rawBarcode && elapsed < differentBarcodeDebounce) {
        return ScanResult.debounced(rawBarcode);
      }
    }

    _isProcessing = true;
    try {
      final product = await database.getProductByBarcode(rawBarcode);
      _lastBarcode = rawBarcode;
      _lastScanTime = DateTime.now();

      if (product == null) {
        ScannerBeepService.playErrorBeep();
        return ScanResult.notFound(rawBarcode);
      }

      // Add to cart optimistically
      cartNotifier.addItem(
        productId: product.id,
        productName: product.name,
        unitPrice: Decimal.parse(product.sellingPrice.toString()),
        barcode: product.barcode,
        unit: product.unit,
      );

      // Trigger physical retail scanner beep tone + haptic pulse
      ScannerBeepService.playSuccessBeep();
      if (onHapticFeedback != null) {
        onHapticFeedback!();
      } else {
        HapticFeedback.mediumImpact();
      }

      return ScanResult.found(product, rawBarcode);
    } finally {
      _isProcessing = false;
    }
  }
}

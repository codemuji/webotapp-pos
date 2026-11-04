import 'package:database/database.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import '../cart/cart_state.dart';

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
/// haptic feedback triggering, and rapid duplicate video frame debouncing.
class BarcodeScanHandler {
  final AppDatabase database;
  final CartNotifier cartNotifier;
  final VoidCallback? onHapticFeedback;
  final Duration debounceDuration;

  String? _lastBarcode;
  DateTime? _lastScanTime;

  BarcodeScanHandler({
    required this.database,
    required this.cartNotifier,
    this.onHapticFeedback,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  /// Processes a raw barcode detected by camera or hardware scanner.
  Future<ScanResult> onBarcodeScanned(String rawBarcode) async {
    final now = DateTime.now();

    // Check debounce for identical barcode within debounce window
    if (_lastBarcode == rawBarcode && _lastScanTime != null) {
      final elapsed = now.difference(_lastScanTime!);
      if (elapsed < debounceDuration) {
        return ScanResult.debounced(rawBarcode);
      }
    }

    _lastBarcode = rawBarcode;
    _lastScanTime = now;

    final product = await database.getProductByBarcode(rawBarcode);
    if (product == null) {
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

    // Trigger haptic feedback
    if (onHapticFeedback != null) {
      onHapticFeedback!();
    } else {
      HapticFeedback.lightImpact();
    }

    return ScanResult.found(product, rawBarcode);
  }
}


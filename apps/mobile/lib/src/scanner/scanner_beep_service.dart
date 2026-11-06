import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays hardware-level retail barcode scanner sound feedback.
class ScannerBeepService {
  static const MethodChannel _channel = MethodChannel('com.grocerypos.mobile/scanner_sound');

  /// Plays the authentic high-pitch POS scanner gun confirmation chirp (2048Hz).
  static void playSuccessBeep() {
    unawaited(() async {
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await _channel.invokeMethod('playBeep');
          return;
        }
      } catch (_) {}

      // Skip desktop SystemSound fallback during automated tests to avoid hanging platform channels
      if (!kReleaseMode && !kProfileMode && !Platform.isAndroid && !Platform.isIOS) {
        return;
      }

      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }());
  }

  /// Plays the uncatalogued barcode error buzz tone.
  static void playErrorBeep() {
    unawaited(() async {
      try {
        if (!kIsWeb && Platform.isAndroid) {
          await _channel.invokeMethod('playErrorBeep');
          return;
        }
      } catch (_) {}

      if (!kReleaseMode && !kProfileMode && !Platform.isAndroid && !Platform.isIOS) {
        return;
      }

      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }());
  }
}

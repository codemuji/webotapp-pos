import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service managing persistent Admin Console PIN authentication and locking.
class AdminAuthService {
  static const String defaultPin = '1234';
  static const String _fileName = 'admin_auth.json';

  static AdminAuthService? _instance;
  static AdminAuthService get instance => _instance ??= AdminAuthService._();

  AdminAuthService._();

  File? _cachedFile;
  String? _testPin;

  /// Allows setting an in-memory test PIN for unit & widget tests.
  @visibleForTesting
  void setTestPin(String? pin) {
    _testPin = pin;
  }

  Future<File> _getConfigFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedFile = File(p.join(dir.path, _fileName));
    return _cachedFile!;
  }

  /// Retrieves the active Admin PIN. Defaults to [defaultPin] if not explicitly configured.
  Future<String> getAdminPin() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return _testPin ?? defaultPin;
    }

    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map.containsKey('admin_pin') && map['admin_pin'].toString().isNotEmpty) {
          return map['admin_pin'].toString();
        }
      }
    } catch (e) {
      debugPrint('AdminAuthService: error reading PIN config: $e');
    }
    return defaultPin;
  }

  /// Verifies whether the entered PIN matches the configured admin PIN.
  Future<bool> verifyPin(String enteredPin) async {
    final activePin = await getAdminPin();
    return enteredPin.trim() == activePin.trim();
  }

  /// Updates the Admin PIN if [currentPin] is verified.
  Future<bool> changeAdminPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin)) {
      return false;
    }
    if (newPin.trim().length < 4) {
      return false;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testPin = newPin.trim();
      return true;
    }

    try {
      final file = await _getConfigFile();
      final data = {'admin_pin': newPin.trim(), 'updated_at': DateTime.now().toIso8601String()};
      await file.writeAsString(jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint('AdminAuthService: error writing new PIN: $e');
      return false;
    }
  }

  /// Resets PIN to factory default ('1234').
  Future<void> resetToDefault() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testPin = null;
      return;
    }

    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

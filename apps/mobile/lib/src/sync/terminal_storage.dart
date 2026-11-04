import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence adapter for mobile POS terminal credentials, bearer tokens, and server URLs.
class TerminalStorage {
  final FlutterSecureStorage? _secureStorage;
  final Map<String, String>? _inMemoryMap;

  static const _keyToken = 'pos_bearer_token';
  static const _keyServerUrl = 'pos_server_url';
  static const _keyStoreName = 'pos_store_name';
  static const _keyDeviceId = 'pos_device_id';

  const TerminalStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _inMemoryMap = null;

  TerminalStorage.inMemory()
      : _secureStorage = null,
        _inMemoryMap = {};

  Future<void> saveCredentials({
    required String bearerToken,
    required String serverUrl,
    required String storeName,
    required String deviceId,
  }) async {
    if (_inMemoryMap != null) {
      _inMemoryMap[_keyToken] = bearerToken;
      _inMemoryMap[_keyServerUrl] = serverUrl;
      _inMemoryMap[_keyStoreName] = storeName;
      _inMemoryMap[_keyDeviceId] = deviceId;
    } else {
      await _secureStorage!.write(key: _keyToken, value: bearerToken);
      await _secureStorage!.write(key: _keyServerUrl, value: serverUrl);
      await _secureStorage!.write(key: _keyStoreName, value: storeName);
      await _secureStorage!.write(key: _keyDeviceId, value: deviceId);
    }
  }

  Future<String?> getBearerToken() async {
    if (_inMemoryMap != null) return _inMemoryMap[_keyToken];
    return _secureStorage!.read(key: _keyToken);
  }

  Future<String?> getServerUrl() async {
    if (_inMemoryMap != null) return _inMemoryMap[_keyServerUrl];
    return _secureStorage!.read(key: _keyServerUrl);
  }

  Future<String?> getStoreName() async {
    if (_inMemoryMap != null) return _inMemoryMap[_keyStoreName];
    return _secureStorage!.read(key: _keyStoreName);
  }

  Future<String?> getDeviceId() async {
    if (_inMemoryMap != null) return _inMemoryMap[_keyDeviceId];
    return _secureStorage!.read(key: _keyDeviceId);
  }

  Future<bool> isPaired() async {
    final token = await getBearerToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    if (_inMemoryMap != null) {
      _inMemoryMap.clear();
    } else {
      await _secureStorage!.deleteAll();
    }
  }
}


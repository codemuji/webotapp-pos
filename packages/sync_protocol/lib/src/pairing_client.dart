import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pairing_models.dart';

/// Result outcome of the pairing handshake between terminal and desktop.
class PairingResult {
  final bool isSuccess;
  final String? bearerToken;
  final String? storeName;
  final String? serverUrl;
  final String? errorMessage;

  const PairingResult.success({
    required this.bearerToken,
    required this.storeName,
    required this.serverUrl,
  })  : isSuccess = true,
        errorMessage = null;

  const PairingResult.failure(this.errorMessage)
      : isSuccess = false,
        bearerToken = null,
        storeName = null,
        serverUrl = null;
}

/// Client facilitating the terminal side of the QR code pairing handshake.
class PairingClient {
  final http.Client _httpClient;

  PairingClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Parses a scanned QR string into a structured [PairingQrPayload].
  static PairingQrPayload? parseQr(String rawQr) {
    return PairingQrPayload.tryParse(rawQr);
  }

  /// Sends a pairing request to the desktop sync server and negotiates credentials.
  Future<PairingResult> pair({
    required PairingQrPayload payload,
    required String deviceId,
    required String deviceName,
  }) async {
    final serverUrl = 'http://${payload.host}:${payload.port}';
    final uri = Uri.parse('$serverUrl/pair');

    try {
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'pairingSecret': payload.pairingSecret,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PairingResult.success(
          bearerToken: data['bearerToken'] as String,
          storeName: data['storeName'] as String,
          serverUrl: serverUrl,
        );
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        return PairingResult.failure(err['error'] as String? ?? 'Pairing rejected (${response.statusCode})');
      }
    } catch (e) {
      return PairingResult.failure('Network connection error: $e');
    }
  }
}


import 'dart:convert';

/// QR Code payload contract scanned by the mobile POS terminal.
class PairingQrPayload {
  final String protocol;
  final String version;
  final String host;
  final int port;
  final String pairingSecret;
  final String storeName;

  const PairingQrPayload({
    this.protocol = 'grocery-pos-sync',
    this.version = '1.0',
    required this.host,
    required this.port,
    required this.pairingSecret,
    required this.storeName,
  });

  Map<String, dynamic> toJson() => {
        'protocol': protocol,
        'version': version,
        'host': host,
        'port': port,
        'pairingSecret': pairingSecret,
        'storeName': storeName,
      };

  factory PairingQrPayload.fromJson(Map<String, dynamic> json) {
    return PairingQrPayload(
      protocol: json['protocol'] as String? ?? 'grocery-pos-sync',
      version: json['version'] as String? ?? '1.0',
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      pairingSecret: json['pairingSecret'] as String,
      storeName: json['storeName'] as String? ?? 'WebotApp Store',
    );
  }

  String toRawString() => jsonEncode(toJson());

  String get baseUrl => 'http://$host:$port';

  static PairingQrPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['protocol'] == 'grocery-pos-sync' &&
          decoded['host'] != null &&
          decoded['port'] != null &&
          decoded['pairingSecret'] != null) {
        return PairingQrPayload.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

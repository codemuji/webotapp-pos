import 'dart:math';

/// Retail-grade Barcode and SKU Generator compliant with GS1 standards.
class BarcodeGenerator {
  static final _random = Random();

  /// Calculates the official GS1 EAN-13 modulo-10 checksum digit.
  /// Sum odd-position digits * 1, even-position digits * 3.
  static String calculateEan13CheckDigit(String twelveDigits) {
    if (twelveDigits.length != 12 || !RegExp(r'^\d{12}$').hasMatch(twelveDigits)) {
      throw ArgumentError('Input must be exactly 12 numeric digits');
    }

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(twelveDigits[i]);
      // Even indexes (0, 2, 4...) have weight 1; odd indexes (1, 3, 5...) have weight 3
      sum += (i % 2 == 0) ? digit : digit * 3;
    }

    final mod = sum % 10;
    return mod == 0 ? '0' : '${10 - mod}';
  }

  /// Generates a compliant GS1 In-Store EAN-13 barcode.
  /// Uses prefix '20' (GS1 in-store restricted distribution prefix) + 10 digits + check digit.
  static String generateEan13({String prefix = '20'}) {
    final now = DateTime.now();
    // 6 digits from millisecond timestamp mod 1,000,000
    final timePart = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    // 4 random digits to avoid same-millisecond collision
    final randPart = _random.nextInt(10000).toString().padLeft(4, '0');
    final twelveDigits = '$prefix$timePart$randPart';
    final checkDigit = calculateEan13CheckDigit(twelveDigits);
    return '$twelveDigits$checkDigit';
  }

  /// Generates a human-friendly store SKU (e.g. SKU-104928 or CAT-7391).
  static String generateStoreSku({String prefix = 'SKU'}) {
    final now = DateTime.now();
    final timePart = (now.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    final randPart = _random.nextInt(100).toString().padLeft(2, '0');
    return '$prefix-$timePart$randPart';
  }

  /// Validates whether a barcode string is a valid EAN-13 number.
  static bool isValidEan13(String barcode) {
    if (barcode.length != 13 || !RegExp(r'^\d{13}$').hasMatch(barcode)) {
      return false;
    }
    final twelve = barcode.substring(0, 12);
    final expectedCheck = calculateEan13CheckDigit(twelve);
    return barcode[12] == expectedCheck;
  }
}


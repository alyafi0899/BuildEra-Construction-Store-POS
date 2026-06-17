import 'package:barcode/barcode.dart';

class BarcodeHelper {
  /// Generates an EAN-13 barcode image as SVG string
  static String generateEAN13Svg(String code) {
    final bc = Barcode.ean13();
    return bc.toSvg(code, width: 200, height: 80);
  }

  /// Generates a Code128 barcode image as SVG string (fallback)
  static String generateCode128Svg(String code) {
    final bc = Barcode.code128();
    return bc.toSvg(code, width: 200, height: 80);
  }

  /// Generates a random unique numeric string for EAN-13 (12 digits, 13th is check digit)
  static String generateRandomEAN13Data() {
    final now = DateTime.now();
    // Use timestamp + some random digits to ensure high uniqueness probability
    // EAN-13 needs 12 digits + 1 check digit
    final part1 = now.millisecondsSinceEpoch.toString().substring(5); // 8 digits
    final part2 = (now.microsecond % 10000).toString().padLeft(4, '0'); // 4 digits
    return (part1 + part2).substring(0, 12);
  }

  /// Validates EAN-13 format
  static bool isValidEAN13(String code) {
    if (code.length != 13) return false;
    if (!RegExp(r'^\d+$').hasMatch(code)) return false;
    
    // Check digit validation
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[12]);
  }
  
  /// Helper to get EAN-13 with check digit from 12 digits
  static String getEAN13WithCheckDigit(String data) {
    if (data.length != 12) return data;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(data[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return data + checkDigit.toString();
  }
}

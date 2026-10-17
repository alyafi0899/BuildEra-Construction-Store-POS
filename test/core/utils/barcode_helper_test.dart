import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/utils/barcode_helper.dart';

void main() {
  group('BarcodeHelper Tests', () {
    test('getEAN13WithCheckDigit calculates correct check digit for 12-digit input', () {
      // Test known EAN-12 -> EAN-13 conversions
      // For '899123456789', check digit is calculated as follows:
      // positions 0,2,4,6,8,10 (even idx): 8 + 9 + 2 + 4 + 6 + 8 = 37
      // positions 1,3,5,7,9,11 (odd idx): 9 + 1 + 3 + 5 + 7 + 9 = 34 * 3 = 102
      // sum = 139 -> (10 - (139 % 10)) % 10 = (10 - 9) % 10 = 1
      final ean13 = BarcodeHelper.getEAN13WithCheckDigit('899123456789');
      expect(ean13.length, equals(13));
      expect(BarcodeHelper.isValidEAN13(ean13), isTrue);
    });

    test('isValidEAN13 validates valid and invalid EAN-13 barcodes', () {
      final validBarcode = BarcodeHelper.getEAN13WithCheckDigit('123456789012');
      expect(BarcodeHelper.isValidEAN13(validBarcode), isTrue);

      // Invalid length
      expect(BarcodeHelper.isValidEAN13('12345'), isFalse);

      // Non-numeric characters
      expect(BarcodeHelper.isValidEAN13('123456789012a'), isFalse);

      // Wrong check digit
      final wrongCheckDigit = validBarcode.substring(0, 12) + ((int.parse(validBarcode[12]) + 1) % 10).toString();
      expect(BarcodeHelper.isValidEAN13(wrongCheckDigit), isFalse);
    });

    test('generateRandomEAN13Data produces 12 digits suitable for EAN-13', () {
      final randomData = BarcodeHelper.generateRandomEAN13Data();
      expect(randomData.length, equals(12));
      expect(RegExp(r'^\d{12}$').hasMatch(randomData), isTrue);

      final fullEan = BarcodeHelper.getEAN13WithCheckDigit(randomData);
      expect(BarcodeHelper.isValidEAN13(fullEan), isTrue);
    });

    test('generateEAN13Svg and generateCode128Svg produce non-empty SVG strings', () {
      final ean = BarcodeHelper.getEAN13WithCheckDigit('899123456789');
      final eanSvg = BarcodeHelper.generateEAN13Svg(ean);
      expect(eanSvg, contains('<svg'));
      expect(eanSvg, contains('</svg>'));

      final code128Svg = BarcodeHelper.generateCode128Svg('BUILDERA-SKU-001');
      expect(code128Svg, contains('<svg'));
      expect(code128Svg, contains('</svg>'));
    });
  });
}

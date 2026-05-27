// lib/core/utils/decimal_utils.dart

class DecimalUtils {
  /// Round to [places] decimal places
  static double round(double value, {int places = 2}) {
    final mod = 1.0 * _pow10(places);
    return (value * mod).roundToDouble() / mod;
  }

  /// Truncate trailing zeros, e.g. 2.50 → 2.5, 3.00 → 3
  static String trimZeros(double value) {
    final str = value.toStringAsFixed(10);
    final trimmed = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return trimmed;
  }

  /// Parse string safely, returns [fallback] on error
  static double parse(String value, {double fallback = 0}) {
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }

  /// Clamp a value between [min] and [max]
  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Convert base units to display quantity given a ratio
  /// e.g. 150 kg → 3 sak (ratio = 50 kg/sak)
  static double convertToUnit(double baseQuantity, double conversionRatio) {
    if (conversionRatio <= 0) return baseQuantity;
    return baseQuantity / conversionRatio;
  }

  /// Convert unit quantity to base units
  /// e.g. 3 sak → 150 kg (ratio = 50 kg/sak)
  static double convertToBase(double unitQuantity, double conversionRatio) {
    return unitQuantity * conversionRatio;
  }

  static int _pow10(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) { result *= 10; }
    return result;
  }
}

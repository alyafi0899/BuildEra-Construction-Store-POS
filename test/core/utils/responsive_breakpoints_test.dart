import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/utils/responsive_breakpoints.dart';

void main() {
  group('ResponsiveBreakpoints', () {
    test('classifies phone, tablet, and desktop widths', () {
      expect(ResponsiveBreakpoints.classify(390), ResponsiveSize.phone);
      expect(ResponsiveBreakpoints.classify(800), ResponsiveSize.tablet);
      expect(ResponsiveBreakpoints.classify(1280), ResponsiveSize.desktop);
    });

    test('uses split cashier only when enough width is available', () {
      expect(ResponsiveBreakpoints.useCompactCashier(899), isTrue);
      expect(ResponsiveBreakpoints.useCompactCashier(900), isFalse);
    });

    test('uses compact management pages below the desktop table width', () {
      expect(ResponsiveBreakpoints.useCompactManagementLayout(800), isTrue);
      expect(ResponsiveBreakpoints.useCompactManagementLayout(1199), isTrue);
      expect(ResponsiveBreakpoints.useCompactManagementLayout(1200), isFalse);
    });
  });
}

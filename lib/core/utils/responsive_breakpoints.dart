enum ResponsiveSize { phone, tablet, desktop }

class ResponsiveBreakpoints {
  static const double phoneMaxWidth = 650;
  static const double tabletMaxWidth = 1100;
  static const double cashierSplitMinWidth = 900;

  static ResponsiveSize classify(double width) {
    if (width < phoneMaxWidth) return ResponsiveSize.phone;
    if (width < tabletMaxWidth) return ResponsiveSize.tablet;
    return ResponsiveSize.desktop;
  }

  static bool useCompactCashier(double width) => width < cashierSplitMinWidth;
}

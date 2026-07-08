import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode {
  darkOrange,
  lightBlue,
  lightBlueOrange,
  lightOrangeBlue,
  lightOrangeGreen,
  lightOrange,
}

class ThemeNotifier extends Notifier<AppThemeMode> {
  static const String _key = 'selected_theme_mode';
  late SharedPreferences _prefs;

  @override
  AppThemeMode build() {
    _initPrefs();
    return AppThemeMode.darkOrange;
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getString(_key);
    if (saved != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemeMode.darkOrange,
      );
    }
  }

  void setTheme(AppThemeMode mode) {
    state = mode;
    _prefs.setString(_key, mode.name);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(ThemeNotifier.new);

class AppThemes {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.darkOrange:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: const Color(0xFFFE6A02),
          bg: const Color(0xFF0F1117),
          surface: const Color(0xFF1A1D27),
          surfaceAlt: const Color(0xFF1E2235),
          border: const Color(0xFF2C3050),
        );
      case AppThemeMode.lightBlue:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFF004F81),
          bg: const Color(0xFFF8F9FA),
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF1F3F5),
          border: const Color(0xFFDEE2E6),
        );
      case AppThemeMode.lightBlueOrange:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFF004F81),
          secondary: const Color(0xFFFE6A02),
          bg: const Color(0xFFF8F9FA),
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF1F3F5),
          border: const Color(0xFFDEE2E6),
        );
      case AppThemeMode.lightOrangeBlue:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFFFE6A02),
          secondary: const Color(0xFF004F81),
          bg: const Color(0xFFF8F9FA),
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF1F3F5),
          border: const Color(0xFFDEE2E6),
        );
      case AppThemeMode.lightOrangeGreen:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFFFE6A02),
          secondary: const Color(0xFF00A745),
          bg: const Color(0xFFF8F9FA),
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF1F3F5),
          border: const Color(0xFFDEE2E6),
        );
      case AppThemeMode.lightOrange:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFFFE6A02),
          bg: const Color(0xFFF8F9FA),
          surface: Colors.white,
          surfaceAlt: const Color(0xFFF1F3F5),
          border: const Color(0xFFDEE2E6),
        );
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color bg,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
    Color? secondary,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final textPri = isDark ? const Color(0xFFEAEBF0) : const Color(0xFF212529);
    final textSec = isDark ? const Color(0xFF8B90A7) : const Color(0xFF495057);
    final textMut = isDark ? const Color(0xFF555B7A) : const Color(0xFFADB5BD);

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: primary,
        primary: primary,
        secondary: secondary ?? primary,
        surface: surface,
        onSurface: textPri,
        outline: border,
        error: const Color(0xFFE74C3C),
      ).copyWith(
        surfaceContainerHighest: surfaceAlt,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.barlow(fontSize: 32, fontWeight: FontWeight.w700, color: textPri),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: textPri),
        headlineMedium: GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w600, color: textPri),
        titleLarge: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: textPri),
        titleMedium: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w500, color: textPri),
        bodyLarge: GoogleFonts.spaceGrotesk(fontSize: 14, color: textPri),
        bodyMedium: GoogleFonts.spaceGrotesk(fontSize: 13, color: textSec),
        bodySmall: GoogleFonts.spaceGrotesk(fontSize: 12, color: textMut),
        labelLarge: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textPri),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSec),
        hintStyle: TextStyle(color: textMut),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: textPri, fontSize: 12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(textMut.withValues(alpha: 0.4)),
        radius: const Radius.circular(4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSec,
        indicatorColor: primary,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bg,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textSec),
        selectedLabelTextStyle: TextStyle(color: primary, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: textSec),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// We simplified the theme to be fixed Dark for a professional, high-contrast POS feel.
final themeProvider = Provider<ThemeData>((ref) => AppThemes.darkOrange);

class AppThemes {
  static ThemeData get darkOrange => _buildTheme(
    brightness: Brightness.dark,
    primary: const Color(0xFFFE6A02),
    bg: const Color(0xFF0F1117),
    surface: const Color(0xFF1A1D27),
    surfaceAlt: const Color(0xFF1E2235),
    border: const Color(0xFF2C3050),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color bg,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
  }) {
    final textPri = const Color(0xFFEAEBF0);
    final textSec = const Color(0xFF8B90A7);
    final textMut = const Color(0xFF555B7A);

    final baseTextTheme = ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: primary,
        primary: primary,
        surface: surface,
        onSurface: textPri,
        surfaceContainer: surfaceAlt,
        outlineVariant: border,
        error: const Color(0xFFE74C3C),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(baseTextTheme).copyWith(
        displayLarge: GoogleFonts.barlow(fontSize: 32, fontWeight: FontWeight.w700, color: textPri),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: textPri),
        headlineMedium: GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w600, color: textPri),
        titleLarge: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
        titleMedium: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: textPri),
        bodyLarge: GoogleFonts.spaceGrotesk(fontSize: 15, color: textPri),
        bodyMedium: GoogleFonts.spaceGrotesk(fontSize: 14, color: textSec),
        bodySmall: GoogleFonts.spaceGrotesk(fontSize: 12, color: textMut),
        labelLarge: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textPri),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: textPri, fontSize: 13, fontWeight: FontWeight.w500),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        checkmarkColor: primary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMut,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

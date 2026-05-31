import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0F1117);
  static const Color surface     = Color(0xFF1A1D27);
  static const Color surfaceAlt  = Color(0xFF22263A);
  static const Color card        = Color(0xFF1E2235);
  static const Color border      = Color(0xFF2C3050);
  static const Color accent      = Color(0xFFFF6B35);   // orange
  static const Color accentLight = Color(0xFFFF8C5A);
  static const Color accentDark  = Color(0xFFCC5225);
  static const Color success     = Color(0xFF2ECC71);
  static const Color warning     = Color(0xFFF39C12);
  static const Color danger      = Color(0xFFE74C3C);
  static const Color info        = Color(0xFF3498DB);
  static const Color textPrimary   = Color(0xFFEAEBF0);
  static const Color textSecondary = Color(0xFF8B90A7);
  static const Color textMuted     = Color(0xFF555B7A);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary:   accent,
        secondary: accentLight,
        surface:   surface,
        error:     danger,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   textPrimary,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge:  GoogleFonts.barlow(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium:GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge:    GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium:   GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge:     GoogleFonts.spaceGrotesk(fontSize: 14, color: textPrimary),
        bodyMedium:    GoogleFonts.spaceGrotesk(fontSize: 13, color: textSecondary),
        bodySmall:     GoogleFonts.spaceGrotesk(fontSize: 12, color: textMuted),
        labelLarge:    GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 0.5),
      ),
      cardTheme: CardThemeData(
        color:        card,
        elevation:    0,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle:  const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation:    0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:   surfaceAlt,
        selectedColor:     accent.withValues(alpha: 0.2),
        labelStyle:        const TextStyle(color: textPrimary, fontSize: 12),
        side:              const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(textMuted.withValues(alpha: 0.4)),
        radius: const Radius.circular(4),
      ),
    );
  }
}

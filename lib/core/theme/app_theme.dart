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
  
  // Dark Text
  static const Color textPrimary   = Color(0xFFEAEBF0);
  static const Color textSecondary = Color(0xFF8B90A7);
  static const Color textMuted     = Color(0xFF555B7A);

  // Light Palette
  static const Color bgLight      = Color(0xFFF8F9FA);
  static const Color surfaceLight = Colors.white;
  static const Color surfAltLight = Color(0xFFF1F3F5);
  static const Color borderLight  = Color(0xFFDEE2E6);
  static const Color textPriLight = Color(0xFF212529);
  static const Color textSecLight = Color(0xFF495057);
  static const Color textMutLight = Color(0xFFADB5BD);

  static ThemeData get light {
    return _buildTheme(
      brightness: Brightness.light,
      bg:         bgLight,
      surface:    surfaceLight,
      surfaceAlt: surfAltLight,
      card:       surfaceLight,
      border:     borderLight,
      textPri:    textPriLight,
      textSec:    textSecLight,
      textMut:    textMutLight,
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      brightness: Brightness.dark,
      bg:         bg,
      surface:    surface,
      surfaceAlt: surfaceAlt,
      card:       card,
      border:     border,
      textPri:    textPrimary,
      textSec:    textSecondary,
      textMut:    textMuted,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceAlt,
    required Color card,
    required Color border,
    required Color textPri,
    required Color textSec,
    required Color textMut,
  }) {
    final baseTextTheme = brightness == Brightness.dark 
        ? ThemeData.dark().textTheme 
        : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness:   brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:    accent,
        onPrimary:  Colors.white,
        secondary:  accentLight,
        onSecondary: Colors.white,
        surface:    surface,
        onSurface:  textPri,
        error:      danger,
        onError:    Colors.white,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(baseTextTheme).copyWith(
        displayLarge:  GoogleFonts.barlow(fontSize: 32, fontWeight: FontWeight.w700, color: textPri, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: textPri),
        headlineMedium:GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w600, color: textPri),
        titleLarge:    GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w600, color: textPri),
        titleMedium:   GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w500, color: textPri),
        bodyLarge:     GoogleFonts.spaceGrotesk(fontSize: 14, color: textPri),
        bodyMedium:    GoogleFonts.spaceGrotesk(fontSize: 13, color: textSec),
        bodySmall:     GoogleFonts.spaceGrotesk(fontSize: 12, color: textMut),
        labelLarge:    GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600, color: textPri, letterSpacing: 0.5),
      ),
      cardTheme: CardThemeData(
        color:     card,
        elevation: 0,
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSec),
        hintStyle:  TextStyle(color: textMut),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation:       0,
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side:            const BorderSide(color: accent),
          padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  surfaceAlt,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: textPri),
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior:         SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor:   accent.withValues(alpha: 0.2),
        labelStyle:      TextStyle(color: textPri, fontSize: 12),
        side:            BorderSide(color: border),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(textMut.withValues(alpha: 0.4)),
        radius:     const Radius.circular(4),
      ),
    );
  }
}

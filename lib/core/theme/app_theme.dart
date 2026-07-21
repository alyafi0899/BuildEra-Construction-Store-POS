import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFFFE6A02); // Brand Orange
  static const Color secondary   = Color(0xFF004F81); // Brand Blue
  
  static const Color bg          = Color(0xFFF8F9FA);
  static const Color surface     = Colors.white;
  static const Color surfaceAlt  = Color(0xFFF1F3F5);
  static const Color card        = Colors.white;
  static const Color border      = Color(0xFFE9ECEF);
  
  static const Color success     = Color(0xFF2ECC71);
  static const Color warning     = Color(0xFFF39C12);
  static const Color danger      = Color(0xFFE74C3C);
  static const Color info        = Color(0xFF3498DB);
  
  // Text
  static const Color textPrimary   = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF495057);
  static const Color textMuted     = Color(0xFFADB5BD);

  static ThemeData get light {
    return _buildTheme(Brightness.light);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final baseTextTheme = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness:   brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary:   primary,
        secondary: secondary,
        surface:   surface,
        onSurface: textPrimary,
        error:     danger,
      ).copyWith(
        surfaceContainerHighest: surfaceAlt,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(baseTextTheme).copyWith(
        displayLarge:  GoogleFonts.barlow(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.barlow(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium:GoogleFonts.barlow(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge:    GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium:   GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge:     GoogleFonts.spaceGrotesk(fontSize: 15, color: textPrimary),
        bodyMedium:    GoogleFonts.spaceGrotesk(fontSize: 14, color: textSecondary),
        bodySmall:     GoogleFonts.spaceGrotesk(fontSize: 12, color: textMuted),
        labelLarge:    GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 0.5),
      ),
      cardTheme: CardThemeData(
        color:     card,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape:     RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle:  const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation:       0,
          minimumSize:     const Size(double.infinity, 52), // Touch friendly
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side:            const BorderSide(color: primary),
          minimumSize:     const Size(double.infinity, 52),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:       GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  textPrimary,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: Colors.white),
        shape:            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior:         SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor:   primary.withValues(alpha: 0.15),
        labelStyle:      const TextStyle(color: textPrimary, fontSize: 13),
        side:            const BorderSide(color: border),
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Legacy for compatibility if needed
  static const Color accent = primary;
  static const Color dark = bg; // Not true dark but placeholder
}

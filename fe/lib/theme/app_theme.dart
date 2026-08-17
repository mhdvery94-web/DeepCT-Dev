import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // BRIN Color Palette
  static const Color primary = Color(0xFFB91C1C); // BRIN Red
  static const Color primaryHover = Color(0xFF991B1B);
  static const Color primaryLight = Color(0xFFFEF2F2);
  static const Color primaryDark = Color(0xFF7F1D1D);

  // Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Cool slate off-white
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color textPrimary = Color(0xFF0F172A); // Deep midnight blue
  static const Color textMuted = Color(0xFF64748B); // Steel gray
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E1);

  /// The strip the device's own status bar sits on.
  ///
  /// Deliberately a step darker than [surface] so the clock and battery read
  /// as the system's, not as part of the app's header. An app targeting SDK 36
  /// has no way to stop drawing there, so the only lever left is the colour —
  /// see `_SystemBarStrip` in `main.dart`. Dark status-bar icons stay legible
  /// against it.
  static const Color systemBar = Color(0xFFE2E8F0);

  // Semantic Colors
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color accent = Color(0xFF0369A1); // Academic blue
  static const Color accentLight = Color(0xFFE0F2FE);

  // Typography - Using Google Fonts
  static TextTheme get textTheme {
    return TextTheme(
      // Headings - Lora (Serif)
      displayLarge: GoogleFonts.lora(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.02,
      ),
      displayMedium: GoogleFonts.lora(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.lora(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.lora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.lora(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.lora(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),

      // Body - IBM Plex Sans
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textMuted,
      ),

      // Labels
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 1.0,
      ),
      labelSmall: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textMuted,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: surface,
        onSecondary: surface,
        onSurface: textPrimary,
        onError: surface,
      ),
      textTheme: textTheme,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Sharp corners!
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textPrimary, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: textMuted, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: textMuted, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: textPrimary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: error, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textMuted,
          letterSpacing: 1.0,
        ),
        hintStyle: GoogleFonts.ibmPlexSans(fontSize: 16, color: textMuted),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

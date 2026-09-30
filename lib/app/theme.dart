import 'package:flutter/material.dart';

/// Central theme definition for QuickServe.
/// Design System: Classic Light Theme (Royal Blue & Deep Slate)
class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1E40AF); // Deep Royal Blue
  static const Color primaryBlueHover = Color(0xFF1D4ED8);
  static const Color accentBlue = Color(0xFF2563EB); // Bright Action Blue

  // Neutral Slate Palette
  static const Color slate50 = Color(0xFFF8FAFC); // Background neutral
  static const Color slate100 = Color(0xFFF1F5F9); // Input & secondary container
  static const Color slate200 = Color(0xFFE2E8F0); // Border color
  static const Color slate300 = Color(0xFFCBD5E1); // Muted border
  static const Color slate400 = Color(0xFF94A3B8); // Subtle text
  static const Color slate500 = Color(0xFF64748B); // Secondary text
  static const Color slate700 = Color(0xFF334155); // Dark text
  static const Color slate900 = Color(0xFF0F172A); // Heading text

  // Semantic Status Colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color successBg = Color(0xFFECFDF5);

  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);

  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFEFF6FF);

  static const Color dangerRed = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFEF2F2);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: accentBlue,
      onPrimary: Colors.white,
      secondary: slate700,
      surface: Colors.white,
      onSurface: slate900,
      error: dangerRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: slate50,
      fontFamily: 'Inter',
      
      // Card Styling
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slate200, width: 1),
        ),
      ),

      // Text Selection Theme
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentBlue,
        selectionColor: Color(0xFFBFDBFE),
        selectionHandleColor: accentBlue,
      ),

      // Text Theme
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: slate900, fontSize: 15, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: slate900, fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: slate700, fontSize: 12),
        titleLarge: TextStyle(color: slate900, fontSize: 20, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: slate900, fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: slate900, fontSize: 14, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: slate900, fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: slate700, fontSize: 12, fontWeight: FontWeight.w500),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: slate500, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: slate700, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: primaryBlue, fontSize: 14, fontWeight: FontWeight.w600),
        helperStyle: const TextStyle(color: slate500, fontSize: 12),
        errorStyle: const TextStyle(color: dangerRed, fontSize: 12, fontWeight: FontWeight.w500),
        counterStyle: const TextStyle(color: slate500, fontSize: 12),
        prefixIconColor: slate500,
        suffixIconColor: slate500,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slate200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed, width: 2),
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate900,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: slate200, width: 1),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: slate900,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: slate700),
      ),

      // Bottom Navigation Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accentBlue,
        unselectedItemColor: slate500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: slate200),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        selectedColor: accentBlue,
        side: const BorderSide(color: slate200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: slate700),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Dark Theme (Retained with high contrast slate elements for dark mode compatibility)
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: accentBlue,
      surface: const Color(0xFF1E293B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }
}

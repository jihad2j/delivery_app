import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFFFF5A36); // Vibrant Coral Orange
  static const Color secondary = Color(0xFF6C63FF); // Electric Indigo
  static const Color accent = Color(0xFFFFB800); // Warm Gold

  // Light Theme Colors
  static const Color lightBg = Color(0xFFFAFAFC);
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1E2022);
  static const Color lightTextSecondary = Color(0xFF777E90);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0F1115);
  static const Color darkCard = Color(0xFF181C24);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF9096A2);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Outfit',
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: lightTextSecondary,
          fontFamily: 'Outfit',
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        // ignore: deprecated_member_use
        shadowColor: Colors.black.withOpacity(0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: lightCard,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: darkCard,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: darkTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          color: darkTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        titleLarge: TextStyle(
          color: darkTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleMedium: TextStyle(
          color: darkTextPrimary,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: darkTextPrimary,
          fontFamily: 'Outfit',
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: darkTextSecondary,
          fontFamily: 'Outfit',
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
        ),
        color: darkCard,
      ),
    );
  }

  // Premium Custom UI styles
  static BoxDecoration premiumGradientDeco() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, Color(0xFFFF8038)],
      ),
    );
  }

  static BoxDecoration glassmorphismDeco({required Color cardColor}) {
    return BoxDecoration(
      color: cardColor.withOpacity(0.85),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

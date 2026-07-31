import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary — Natural Herbal Green (Fresh & Healthy vibe)
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color primaryDark = Color(0xFF1B5E20);

  // Brand Secondary — Warm Honey Gold
  static const Color secondary = Color(0xFFF9A825);
  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondaryDark = Color(0xFFF57F17);

  // Accent Colors
  static const Color accentGold = Color(0xFFFFB300);
  static const Color accentTeal = Color(0xFF26A69A);
  static const Color accentPurple = Color(0xFF8E24AA);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFF8F00);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // Light Theme Palette
  static const Color lightBg = Color(0xFFF8F9FC);
  static const Color lightCard = Colors.white;
  static const Color lightSurface = Color(0xFFEEF2F7);
  static const Color lightTextPrimary = Color(0xFF1E232C);
  static const Color lightTextSecondary = Color(0xFF6B7380);
  static const Color lightDivider = Color(0xFFE5E8EE);
  static const Color lightShadow = Color(0x1A1E232C);

  // Dark Theme Palette
  static const Color darkBg = Color(0xFF12151B);
  static const Color darkCard = Color(0xFF1A1F29);
  static const Color darkSurface = Color(0xFF252B37);
  static const Color darkTextPrimary = Color(0xFFF8F9FC);
  static const Color darkTextSecondary = Color(0xFF8A94A6);
  static const Color darkDivider = Color(0xFF2E3541);
  static const Color darkShadow = Color(0x40000000);
}

// Backward compatibility aliases (مستخدمة في صفحات قديمة للحفاظ على التوافق)
@Deprecated('Use AppColors.primary instead')
const Color primary = AppColors.primary;
@Deprecated('Use AppColors.primaryDark instead')
const Color primaryDark = AppColors.primaryDark;
@Deprecated('Use AppColors.secondary instead')
const Color secondary = AppColors.secondary;
@Deprecated('Use AppColors.accentTeal instead')
const Color accent = AppColors.accentGold;
@Deprecated('Use AppColors.warning instead')
const Color warning = AppColors.warning;
@Deprecated('Use AppColors.error instead')
const Color error = AppColors.error;

@Deprecated('Use AppColors.lightBg instead')
const Color lightBg = AppColors.lightBg;
@Deprecated('Use AppColors.lightCard instead')
const Color lightCard = AppColors.lightCard;
@Deprecated('Use AppColors.lightSurface instead')
const Color lightSurface = AppColors.lightSurface;
@Deprecated('Use AppColors.lightTextPrimary instead')
const Color lightTextPrimary = AppColors.lightTextPrimary;
@Deprecated('Use AppColors.lightTextSecondary instead')
const Color lightTextSecondary = AppColors.lightTextSecondary;

@Deprecated('Use AppColors.darkBg instead')
const Color darkBg = AppColors.darkBg;
@Deprecated('Use AppColors.darkCard instead')
const Color darkCard = AppColors.darkCard;
@Deprecated('Use AppColors.darkSurface instead')
const Color darkSurface = AppColors.darkSurface;
@Deprecated('Use AppColors.darkTextPrimary instead')
const Color darkTextPrimary = AppColors.darkTextPrimary;
@Deprecated('Use AppColors.darkTextSecondary instead')
const Color darkTextSecondary = AppColors.darkTextSecondary;

class AppTheme {
  // Backward-compatible static const colors — map to new AppColors palette
  static const Color primary = AppColors.primary;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondary = AppColors.secondary;
  static const Color accent = AppColors.accentGold;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;

  static const Color lightBg = AppColors.lightBg;
  static const Color lightCard = AppColors.lightCard;
  static const Color lightSurface = AppColors.lightSurface;
  static const Color lightTextPrimary = AppColors.lightTextPrimary;
  static const Color lightTextSecondary = AppColors.lightTextSecondary;

  static const Color darkBg = AppColors.darkBg;
  static const Color darkCard = AppColors.darkCard;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkTextPrimary = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;

  static const String fontFamily = 'Outfit';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightCard,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFC8E6C9),
        onPrimaryContainer: Color(0xFF1B5E20),
        secondary: AppColors.secondary,
        onSecondary: Color(0xFF3E2723),
        secondaryContainer: Color(0xFFFFECB3),
        onSecondaryContainer: Color(0xFFE65100),
        surface: AppColors.lightCard,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 22,
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.lightTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.lightTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.lightTextSecondary,
        suffixIconColor: AppColors.lightTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.lightDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        showCheckmark: false,
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.lightTextPrimary,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        headlineLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        headlineMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        headlineSmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        titleSmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        bodyLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: AppColors.lightTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: AppColors.lightTextSecondary,
          fontFamily: fontFamily,
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.lightTextSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: AppColors.lightShadow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.lightDivider, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        color: AppColors.lightCard,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightCard,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(size: 22, color: AppColors.lightTextSecondary),
        ),
        height: 68,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.lightTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.lightTextPrimary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: AppColors.lightDivider,
        dragHandleSize: Size(44, 5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: 64,
          height: 64,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.3);
          }
          return Colors.grey.shade300;
        }),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.lightTextSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.lightTextSecondary;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 24,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: AppColors.lightTextSecondary,
        textColor: AppColors.lightTextPrimary,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.lightTextPrimary,
        ),
        subtitleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: AppColors.lightTextSecondary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lightSurface,
        circularTrackColor: AppColors.lightSurface,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        smallSize: 8,
        largeSize: 18,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextPrimary,
        size: 22,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.lightCard,
        scrimColor: AppColors.lightTextPrimary.withValues(alpha: 0.5),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkCard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Color(0xFF0D3311),
        primaryContainer: Color(0xFF1B5E20),
        onPrimaryContainer: Color(0xFFC8E6C9),
        secondary: AppColors.secondaryLight,
        onSecondary: Color(0xFF3E2723),
        secondaryContainer: Color(0xFFE65100),
        onSecondaryContainer: Color(0xFFFFECB3),
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        surfaceVariant: AppColors.darkSurface,
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF5A0000),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 22,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 22,
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primaryLight,
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.darkTextSecondary,
        suffixIconColor: AppColors.darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.darkDivider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.darkDivider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: const Color(0xFF0D3311),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedColor: AppColors.primaryLight.withValues(alpha: 0.2),
        showCheckmark: false,
        secondarySelectedColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.darkTextPrimary,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: -0.3,
        ),
        displaySmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        headlineLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        headlineMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        headlineSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        titleMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        titleSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        bodyLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: AppColors.darkTextSecondary,
          fontFamily: fontFamily,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: AppColors.darkTextSecondary,
          fontFamily: fontFamily,
          fontSize: 12,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.darkTextSecondary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: AppColors.darkShadow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.darkDivider, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        color: AppColors.darkCard,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedIconTheme: IconThemeData(size: 24),
        unselectedIconTheme: IconThemeData(size: 22),
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(size: 22, color: AppColors.darkTextSecondary),
        ),
        height: 68,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.darkTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.darkTextSecondary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: AppColors.darkDivider,
        dragHandleSize: Size(44, 5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: const Color(0xFF0D3311),
        elevation: 6,
        highlightElevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        largeSizeConstraints: const BoxConstraints.tightFor(
          width: 64,
          height: 64,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return Colors.grey.shade600;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight.withValues(alpha: 0.4);
          }
          return Colors.grey.withValues(alpha: 0.3);
        }),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(const Color(0xFF0D3311)),
        side: const BorderSide(color: AppColors.darkTextSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 24,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: AppColors.darkTextSecondary,
        textColor: AppColors.darkTextPrimary,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.darkTextPrimary,
        ),
        subtitleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: AppColors.darkTextSecondary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.darkSurface,
        circularTrackColor: AppColors.darkSurface,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: const Color(0xFFFF6B6B),
        textColor: Colors.white,
        smallSize: 8,
        largeSize: 18,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextPrimary,
        size: 22,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.darkCard,
        scrimColor: Colors.black.withValues(alpha: 0.6),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
      ),
    );
  }

  // Gradient Decorations
  static BoxDecoration primaryGradient({BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primaryLight,
          AppColors.primary,
          AppColors.primaryDark,
        ],
        stops: [0.0, 0.5, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration secondaryGradient({BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.secondaryLight,
          AppColors.secondary,
          AppColors.secondaryDark,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.secondary.withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration sunsetGradient({BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primaryLight,
          AppColors.primary,
          AppColors.accentGold,
          AppColors.secondaryDark,
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration oceanGradient({BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.accentTeal, Color(0xFF0288D1), Color(0xFF283593)],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentTeal.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration successGradient({BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primaryLight,
          AppColors.primary,
          AppColors.primaryDark,
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.success.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration walletGradient({
    bool isSecondary = false,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isSecondary
            ? [AppColors.accentPurple, const Color(0xFFB388FF)]
            : [AppColors.primary, AppColors.primaryLight],
      ),
      boxShadow: [
        BoxShadow(
          color: (isSecondary ? AppColors.accentPurple : AppColors.primary)
              .withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Glass morphism card
  static BoxDecoration glassCard({
    required Color cardColor,
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: cardColor.withValues(alpha: 0.9),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.12),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // Status Badge decoration
  static BoxDecoration statusBadge(Color color, {double radius = 20}) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
    );
  }

  // Soft card decoration (no gradient)
  static BoxDecoration softCard({
    required Color bgColor,
    Color? borderColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(color: borderColor ?? AppColors.lightDivider),
    );
  }

  // Helper: get status color
  static Color getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.error;
      case 'restaurant_accepted':
      case 'preparing':
        return AppColors.warning;
      case 'ready':
        return AppColors.success;
      case 'delivery_accepted':
      case 'onTheWay':
        return AppColors.secondary;
      case 'delivered_pending':
        return AppColors.accentPurple;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'open':
        return AppColors.success;
      case 'closed':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  // Helper: get status text in Arabic
  static String getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'restaurant_accepted':
        return 'مقبول من المطعم';
      case 'preparing':
        return 'جاري التحضير';
      case 'ready':
        return 'جاهز للتوصيل';
      case 'delivery_accepted':
        return 'مقبول من الكابتن';
      case 'onTheWay':
        return 'في الطريق';
      case 'delivered_pending':
        return 'بانتظار العميل';
      case 'delivered':
        return 'تم التوصيل بنجاح';
      case 'cancelled':
        return 'ملغى';
      case 'open':
        return 'مفتوح';
      case 'closed':
        return 'مغلق';
      default:
        return status ?? '';
    }
  }

  // Role label helper
  static String getRoleLabel(String? role) {
    switch (role) {
      case 'customer':
        return 'زبون';
      case 'driver':
        return 'كابتن توصيل';
      case 'restaurant':
        return 'صاحب مطعم';
      case 'admin':
        return 'مدير النظام';
      default:
        return role ?? 'مستخدم';
    }
  }

  // Icon helper for address label
  static IconData getAddressIcon(String? label) {
    if (label == null) return Icons.location_on_rounded;
    if (label.contains('المنزل') ||
        label.contains('بيتي') ||
        label.contains('منزل')) {
      return Icons.home_rounded;
    }
    if (label.contains('العمل') ||
        label.contains('مكتب') ||
        label.contains('شرك')) {
      return Icons.work_rounded;
    }
    return Icons.place_rounded;
  }

  // ───────────────────────── Backward compatibility helpers ─────────────────────────

  /// [Deprecated] Use [AppTheme.primaryGradient()] instead.
  @Deprecated('Use primaryGradient() instead')
  static BoxDecoration premiumGradientDeco() => primaryGradient();

  /// [Deprecated] Use [AppTheme.walletGradient()] instead.
  @Deprecated('Use walletGradient() instead')
  static BoxDecoration walletGradientDeco({bool isSecondary = false}) =>
      walletGradient(isSecondary: isSecondary);

  /// [Deprecated] Use [AppTheme.glassCard()] instead.
  @Deprecated('Use glassCard() instead')
  static BoxDecoration glassmorphismDeco({Color? cardColor}) => glassCard(
    cardColor: cardColor ?? AppColors.darkCard.withValues(alpha: 0.95),
  );

  /// [Deprecated] Use [AppTheme.softCard()] instead.
  @Deprecated('Use softCard() instead')
  static BoxDecoration softCardDeco({
    required Color bgColor,
    Color? borderColor,
    BorderRadius? borderRadius,
  }) => softCard(
    bgColor: bgColor,
    borderColor: borderColor,
    borderRadius: borderRadius,
  );

  /// [Deprecated] Use [AppTheme.statusBadge()] instead.
  @Deprecated('Use statusBadge() instead')
  static BoxDecoration statusBadgeDeco(Color color, {double radius = 20}) =>
      statusBadge(color, radius: radius);
}

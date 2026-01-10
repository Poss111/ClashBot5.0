import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppBrandColors {
  static const Color primary = Color(0xFF6D28D9); // deeper purple for contrast
  static const Color accent = Color(0xFF8B5CF6); // secondary for chips/ctas
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);
  static const Color error = Color(0xFFEF4444);

  static const Color neutralSurface = Color(0xFFF6F7FB);
  static const Color neutralSurfaceStrong = Color(0xFFE8ECF5);
  static const Color darkSurface = Color(0xFF0E1628);
  static const Color darkCard = Color(0xFF111827);

  static const Color successSurface = Color(0xFFECFDF3);
  static const Color warningSurface = Color(0xFFFFF7ED);
  static const Color infoSurface = Color(0xFFE0F2FE);
  static const Color errorSurface = Color(0xFFFEE2E2);

  static const Color onSurfaceBright = Color(0xFFE5E7EB);
  static const Color onSurfaceMuted = Color(0xFFA3AED0);
  static const Color onSurfaceVariant = Color(0xFFC7D2FE);
}

class AppTheme {
  static const _fontFamily = 'Roboto';

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppBrandColors.primary,
      brightness: brightness,
    ).copyWith(
      secondary: AppBrandColors.accent,
      tertiary: const Color(0xFF0EA5E9),
      surface: isDark ? AppBrandColors.darkSurface : AppBrandColors.neutralSurface,
      surfaceVariant: isDark ? const Color(0xFF1B2335) : AppBrandColors.neutralSurfaceStrong,
      error: AppBrandColors.error,
      onSurface: isDark ? AppBrandColors.onSurfaceBright : null,
      onSurfaceVariant: isDark ? AppBrandColors.onSurfaceVariant : null,
      onPrimary: isDark ? Colors.white : null,
      onSecondary: isDark ? const Color(0xFF0A0A0F) : null,
    );

    final cardColor = isDark ? AppBrandColors.darkCard : Colors.white;
    final scaffoldBg = isDark ? AppBrandColors.darkSurface : AppBrandColors.neutralSurface;

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: baseScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: cardColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseScheme.surfaceVariant.withOpacity(isDark ? 0.4 : 1),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: baseScheme.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: baseScheme.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: baseScheme.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseScheme.primary,
          foregroundColor: baseScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: baseScheme.secondary,
          foregroundColor: baseScheme.onSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: baseScheme.primary.withOpacity(0.5)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: baseScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: baseScheme.surfaceVariant.withOpacity(isDark ? 0.5 : 1),
        selectedColor: baseScheme.primary.withOpacity(0.18),
        disabledColor: baseScheme.surfaceVariant,
        secondarySelectedColor: baseScheme.secondary.withOpacity(0.16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: TextStyle(color: baseScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: baseScheme.onSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: cardColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: baseScheme.inverseSurface,
        contentTextStyle: TextStyle(color: baseScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: baseScheme.primary),
      dividerTheme: DividerThemeData(
        color: baseScheme.outlineVariant,
        thickness: 1,
        space: 16,
      ),
    );
  }
}

class AppDateFormats {
  static const String standardPattern = 'EEE, MMM d yyyy · h:mm a';
  static const String longPattern = 'EEEE, MMM d yyyy · h:mm a';
  static const String justTimePattern = 'h:mm a';

  static String formatStandard(DateTime dt) => DateFormat(standardPattern).format(dt);
  static String formatLong(DateTime dt) => DateFormat(longPattern).format(dt);
  static String formatJustTime(DateTime dt) => DateFormat(justTimePattern).format(dt);
}


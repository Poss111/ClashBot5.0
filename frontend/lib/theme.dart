import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  static const _fontFamily = 'Roboto';

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        cardColor: Colors.white,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardColor: const Color(0xFF111827),
      );
}

class AppDateFormats {
  static const String standardPattern = 'EEE, MMM d yyyy · h:mm a';
  static const String longPattern = 'EEEE, MMM d yyyy · h:mm a';

  static String formatStandard(DateTime dt) => DateFormat(standardPattern).format(dt);
  static String formatLong(DateTime dt) => DateFormat(longPattern).format(dt);
}


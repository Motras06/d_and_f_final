import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1976D2);
  static const Color accent = Color(0xFF42A5F5);

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF5F5F5),
      error: error,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF212121)),
      bodyMedium: TextStyle(color: Color(0xFF757575)),
    ),
    cardColor: Colors.white,
    dividerColor: Colors.grey[300],
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
      error: error,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    cardColor: const Color(0xFF1E1E1E),
    dividerColor: Colors.grey[800],
  );
}

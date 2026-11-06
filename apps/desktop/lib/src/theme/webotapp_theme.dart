import 'package:flutter/material.dart';

/// WebotApp Official Brand Theme & Color Palette
/// Derived from webotapp.com brand design system
class WebotAppTheme {
  // Primary brand accent
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color primaryGreenDark = Color(0xFF009624);
  static const Color primaryGreenLight = Color(0xFFB9F6CA);

  // Modern Slate UI Neutrals
  static const Color darkSlate = Color(0xFF0F172A); // slate-900
  static const Color slate800 = Color(0xFF1E293B);  // slate-800
  static const Color slate700 = Color(0xFF334155);  // slate-700
  static const Color slate600 = Color(0xFF475569);  // slate-600
  static const Color slate500 = Color(0xFF64748B);  // slate-500
  static const Color slate400 = Color(0xFF94A3B8);  // slate-400
  static const Color slate200 = Color(0xFFE2E8F0);  // slate-200
  static const Color slate100 = Color(0xFFF1F5F9);  // slate-100
  static const Color slate50 = Color(0xFFF8FAFC);   // slate-50

  // WebotApp 4-Pill Mark Colors
  static const Color pillRed = Color(0xFFF03D3D);
  static const Color pillGreen = Color(0xFF00C853);
  static const Color pillBlue = Color(0xFF1E6FFF);
  static const Color pillOrange = Color(0xFFFF9900);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      surface: Colors.white,
      onPrimary: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: slate50,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: darkSlate,
      elevation: 0,
      centerTitle: false,
    ),
  );
}


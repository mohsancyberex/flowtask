import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 64.0; // Increased for modern airy feel

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);

  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
}

class AppRadius {
  static const double sm = 12.0;
  static const double md = 18.0;
  static const double lg = 28.0; // Pill shapes
  static const double xl = 40.0;
}

class AppColors {
  // Light Mode
  static const lightBg = Color(0xFFF8F9FA); // Off-white
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF111827); // Almost black
  static const lightTextSecondary = Color(0xFF6B7280); // Cool grey
  static const lightAccent = Color(0xFF111827); // Monochrome accent (Black)
  static const lightAccentSecondary = Color(0xFFE5E7EB); // Light grey for buttons

  // Dark Mode
  static const darkBg = Color(0xFF000000); // True black
  static const darkSurface = Color(0xFF1C1C1E); // Dark grey
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFA1A1AA);
  static const darkAccent = Color(0xFFFFFFFF); // Monochrome accent (White)
  static const darkAccentSecondary = Color(0xFF27272A);
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBg,
  colorScheme: const ColorScheme.light(
    primary: AppColors.lightAccent,
    onPrimary: AppColors.lightSurface,
    secondary: AppColors.lightAccentSecondary,
    onSecondary: AppColors.lightTextPrimary,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    outline: AppColors.lightTextSecondary,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.lightBg,
    foregroundColor: AppColors.lightTextPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.inter(
      color: AppColors.lightTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    margin: EdgeInsets.zero,
  ),
  textTheme: _buildTextTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
  iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.darkAccent,
    onPrimary: AppColors.darkBg,
    secondary: AppColors.darkAccentSecondary,
    onSecondary: AppColors.darkTextPrimary,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    outline: AppColors.darkTextSecondary,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBg,
    foregroundColor: AppColors.darkTextPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.inter(
      color: AppColors.darkTextPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    margin: EdgeInsets.zero,
  ),
  textTheme: _buildTextTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
  iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
);

TextTheme _buildTextTheme(Color primary, Color secondary) {
  return TextTheme(
    displayLarge: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1.5, color: primary),
    displayMedium: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -1.0, color: primary),
    headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: primary),
    headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: primary),
    titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: primary),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: primary),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: secondary),
  );
}

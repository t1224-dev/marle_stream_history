import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme configuration
class AppTheme {
  /// Primary colors based on brand colors
  static const Color primaryColor = Color(0xFF8AD0E9); // Water blue
  static const Color secondaryColor = Color(0xFFC8B5F0); // Light purple
  static const Color accentColor = Color(0xFFFFFFFF); // White
  static const Color backgroundColor = Color(0xFFF5FAFF); // Light blue-white

  /// Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF191C1D); // Dark navy
  static const Color darkSurfaceColor = Color(0xFF262A2B);
  static const Color darkAccentColor = Color(
    0xFF8FD5E9,
  ); // Lighter blue for dark theme

  /// Create the light theme
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surfaceContainer: Colors.white,
        surface: backgroundColor, // Changed from background (deprecated),
        error: Colors.redAccent,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: primaryColor.withAlpha(
          204,
        ), // Changed from withOpacity(0.8),
        labelTextStyle: WidgetStateProperty.all(
          // Changed from MaterialStateProperty to WidgetStateProperty,
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: Colors.black87),
          displayMedium: TextStyle(color: Colors.black87),
          displaySmall: TextStyle(color: Colors.black87),
          headlineMedium: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Create the dark theme
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: darkAccentColor,
        secondary: secondaryColor.withAlpha(
          179,
        ), // Changed from withOpacity(0.7),
        surfaceContainer: darkSurfaceColor,
        surface: darkBackgroundColor, // Changed from background (deprecated),
        error: Colors.redAccent,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackgroundColor,
        indicatorColor: darkAccentColor.withAlpha(
          102,
        ), // Changed from withOpacity(0.4),
        labelTextStyle: WidgetStateProperty.all(
          // Changed from MaterialStateProperty to WidgetStateProperty,
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      cardTheme: CardTheme(
        color: darkSurfaceColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccentColor,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(ThemeData.dark().textTheme),
    );
  }
}

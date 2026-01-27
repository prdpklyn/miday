
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFFF5F5F5); // Light Gray
  static const Color surface = Colors.white;
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF757575);
  
  static const Color accentBlue = Color(0xFF4A90D9);
  static const Color accentRed = Color(0xFFFF4444);
  static const Color noteYellow = Color(0xFFFFF9E6);
  static const Color noteTagYellow = Color(0xFFFFEDA6);

  // Text Styles
  static TextStyle get heading1 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryText,
      );

  static TextStyle get sectionHeader => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: secondaryText,
        letterSpacing: 1.2,
      );

  static TextStyle get bodyBold => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      );

  static TextStyle get bodyRegular => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryText,
      );

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: accentBlue,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: accentBlue,
      ),
      textTheme: TextTheme(
        displayLarge: heading1,
        titleMedium: sectionHeader,
        bodyLarge: bodyBold,
        bodyMedium: bodyRegular,
      ),
      useMaterial3: true,
    );
  }
}

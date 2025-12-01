import 'package:flutter/material.dart';

class AppTokens {
  // --- Light Mode Colors ---
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightBgSecondary = Color(0xFFF7F7F8);
  static const Color lightBgTertiary = Color(0xFFEBEBEB);
  static const Color lightText = Color(0xFF1F1F1F);
  static const Color lightTextSecondary = Color(0xFF6B6B6B);
  static const Color lightTextMuted = Color(0xFF9B9B9B);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightAccent = Color(0xFF20808D); // Teal
  static const Color lightAccentLight = Color(0x1A20808D); // rgba(32, 128, 141, 0.1)
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightInputBg = Color(0xFFF7F7F8);

  // --- Dark Mode Colors ---
  static const Color darkBg = Color(0xFF191A1A);
  static const Color darkBgSecondary = Color(0xFF232627);
  static const Color darkBgTertiary = Color(0xFF2D2F30);
  static const Color darkText = Color(0xFFECECEC);
  static const Color darkTextSecondary = Color(0xFF9B9B9B);
  static const Color darkTextMuted = Color(0xFF6B6B6B);
  static const Color darkBorder = Color(0xFF333535);
  static const Color darkAccent = Color(0xFF20B8CB); // Bright Teal
  static const Color darkAccentLight = Color(0x2620B8CB); // rgba(32, 184, 203, 0.15)
  static const Color darkCardBg = Color(0xFF232627);
  static const Color darkInputBg = Color(0xFF232627);

  // --- Spacing ---
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing60 = 60.0;

  // --- Border Radius ---
  static const double radius8 = 8.0;
  static const double radius10 = 10.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radiusPill = 100.0;

  // --- Animation ---
  static const Duration animDurationFast = Duration(milliseconds: 200);
  static const Duration animDurationMedium = Duration(milliseconds: 300);
  static const Curve animCurve = Curves.easeInOut;
}

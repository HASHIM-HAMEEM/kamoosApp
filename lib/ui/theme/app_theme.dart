import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData light = _buildTheme(Brightness.light);
  static ThemeData dark = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppTokens.darkBg : AppTokens.lightBg;
    final bgSecondary = isDark
        ? AppTokens.darkBgSecondary
        : AppTokens.lightBgSecondary;
    final text = isDark ? AppTokens.darkText : AppTokens.lightText;
    final textSecondary = isDark
        ? AppTokens.darkTextSecondary
        : AppTokens.lightTextSecondary;
    final textMuted = isDark
        ? AppTokens.darkTextMuted
        : AppTokens.lightTextMuted;
    final border = isDark ? AppTokens.darkBorder : AppTokens.lightBorder;
    final accent = isDark ? AppTokens.darkAccent : AppTokens.lightAccent;
    final cardBg = isDark ? AppTokens.darkCardBg : AppTokens.lightCardBg;
    final inputBg = isDark ? AppTokens.darkInputBg : AppTokens.lightInputBg;

    final baseTextTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: bg,
        onSurface: text,
        outline: border,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: text),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spacing20,
          vertical: AppTokens.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: textMuted, fontSize: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spacing16,
            vertical: AppTokens.spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius10),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 24),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgSecondary,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Helper for Arabic Text
  static TextStyle arabicTextStyle(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.notoNaskhArabic(
      fontSize: fontSize ?? 20,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color ?? theme.colorScheme.onSurface,
      height: 1.5,
    );
  }

  // Get current theme colors
  static AppColors colors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors(
      bg: isDark ? AppTokens.darkBg : AppTokens.lightBg,
      bgSecondary: isDark
          ? AppTokens.darkBgSecondary
          : AppTokens.lightBgSecondary,
      bgTertiary: isDark ? AppTokens.darkBgTertiary : AppTokens.lightBgTertiary,
      text: isDark ? AppTokens.darkText : AppTokens.lightText,
      textSecondary: isDark
          ? AppTokens.darkTextSecondary
          : AppTokens.lightTextSecondary,
      textMuted: isDark ? AppTokens.darkTextMuted : AppTokens.lightTextMuted,
      border: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
      accent: isDark ? AppTokens.darkAccent : AppTokens.lightAccent,
      accentLight: isDark
          ? AppTokens.darkAccentLight
          : AppTokens.lightAccentLight,
      cardBg: isDark ? AppTokens.darkCardBg : AppTokens.lightCardBg,
      inputBg: isDark ? AppTokens.darkInputBg : AppTokens.lightInputBg,
    );
  }
}

class AppColors {
  final Color bg;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color accentLight;
  final Color cardBg;
  final Color inputBg;

  AppColors({
    required this.bg,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.accentLight,
    required this.cardBg,
    required this.inputBg,
  });
}

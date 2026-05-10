import 'package:flutter/material.dart';
import 'database_service.dart';
import '../utils/app_localizations.dart';

class SettingsService extends ChangeNotifier {
  final DatabaseService _db;

  Locale _locale = const Locale('en');
  bool _showDiacritics = true;
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScale = 1.0;
  bool _isLoaded = false;

  SettingsService(this._db) {
    _loadSettings();
  }

  Locale get locale => _locale;
  bool get showDiacritics => _showDiacritics;
  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  bool get isLoaded => _isLoaded;

  /// Clamp to a sane range. Below 0.85 the UI chrome breaks; above 1.35
  /// long Arabic words overflow cards. These match the stops exposed in
  /// the settings slider.
  static const double minTextScale = 0.85;
  static const double maxTextScale = 1.35;

  AppLocalizations get strings => AppLocalizations(_locale);

  Future<void> _loadSettings() async {
    final langCode = await _db.getSetting('language_code');
    final diacritics = await _db.getSetting('show_diacritics');
    final theme = await _db.getSetting('theme_mode');
    final scale = await _db.getSetting('text_scale');

    if (langCode != null) {
      _locale = Locale(langCode);
    }

    if (diacritics != null) {
      _showDiacritics = diacritics == 'true';
    }

    if (theme != null) {
      _themeMode = _decodeTheme(theme);
    }

    if (scale != null) {
      final parsed = double.tryParse(scale);
      if (parsed != null) {
        _textScale = parsed.clamp(minTextScale, maxTextScale);
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _db.setSetting('language_code', locale.languageCode);
    notifyListeners();
  }

  Future<void> toggleDiacritics(bool value) async {
    _showDiacritics = value;
    await _db.setSetting('show_diacritics', value.toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _db.setSetting('theme_mode', _encodeTheme(mode));
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final isDark = _themeMode == ThemeMode.dark;
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setTextScale(double value) async {
    final clamped = value.clamp(minTextScale, maxTextScale);
    if ((clamped - _textScale).abs() < 0.001) return;
    _textScale = clamped;
    await _db.setSetting('text_scale', _textScale.toStringAsFixed(2));
    notifyListeners();
  }

  String _encodeTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _decodeTheme(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  // Helper to strip diacritics if setting is off
  String formatText(String text) {
    if (_showDiacritics) return text;
    return _stripDiacritics(text);
  }

  String _stripDiacritics(String input) {
    final diacritics = RegExp(r'[\u064B-\u065F\u0670]');
    return input.replaceAll(diacritics, '');
  }
}

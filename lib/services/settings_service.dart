import 'package:flutter/material.dart';
import 'database_service.dart';
import '../utils/app_localizations.dart';

class SettingsService extends ChangeNotifier {
  final DatabaseService _db;

  Locale _locale = const Locale('en');
  bool _showDiacritics = true;
  bool _isLoaded = false;

  SettingsService(this._db) {
    _loadSettings();
  }

  Locale get locale => _locale;
  bool get showDiacritics => _showDiacritics;
  bool get isLoaded => _isLoaded;

  AppLocalizations get strings => AppLocalizations(_locale);

  Future<void> _loadSettings() async {
    final langCode = await _db.getSetting('language_code');
    final diacritics = await _db.getSetting('show_diacritics');

    if (langCode != null) {
      _locale = Locale(langCode);
    }

    if (diacritics != null) {
      _showDiacritics = diacritics == 'true';
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

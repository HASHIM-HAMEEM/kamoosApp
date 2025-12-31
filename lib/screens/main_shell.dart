import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'qamus_home_screen.dart';
import 'library_screen.dart';
import 'discover_screen.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../services/settings_service.dart';
import '../utils/app_localizations.dart';

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const MainShell({super.key, required this.onToggleTheme});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _showSettings = false;

  void _showSettingsSheet() {
    setState(() => _showSettings = true);
  }

  void _hideSettingsSheet() {
    setState(() => _showSettings = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final settings = Provider.of<SettingsService>(context);
    final strings = settings.strings;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Main Content
          IndexedStack(
            index: _currentIndex,
            children: [
              QamusHomeScreen(onSettings: _showSettingsSheet),
              const LibraryScreen(),
              const DiscoverScreen(),
            ],
          ),

          // Settings Sheet
          if (_showSettings)
            GestureDetector(
              onTap: _hideSettingsSheet,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap-through
                    child: _buildSettingsSheet(colors, settings),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: colors.bgSecondary.withValues(
            alpha: 0.8,
          ), // Glassmorphism base
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur effect
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(
                    0,
                    Icons.search_rounded,
                    strings.get('search'),
                    colors,
                  ),
                  _buildNavItem(
                    1,
                    Icons.bookmark_rounded,
                    strings.get('library'),
                    colors,
                  ),
                  _buildNavItem(
                    2,
                    Icons.explore_rounded,
                    strings.get('discover'),
                    colors,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    AppColors colors,
  ) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : colors.textMuted,
                size: 24,
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSheet(AppColors colors, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = settings.strings;

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            strings.get('settings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 24),

          _buildSettingItem(
            colors,
            label: strings.get('appearance'),
            description: isDark
                ? strings.get('dark_mode')
                : strings.get('light_mode'),
            trailing: _buildToggle(colors, isDark, widget.onToggleTheme),
          ),
          _buildSettingItem(
            colors,
            label: strings.get('interface_language'),
            description: _getLanguageName(settings.locale.languageCode),
            trailing: Icon(Icons.chevron_right, color: colors.accent),
            onTap: () => _showLanguageSelector(context, settings),
          ),
          _buildSettingItem(
            colors,
            label: strings.get('show_diacritics'),
            description: strings.get('diacritics_desc'),
            trailing: _buildToggle(
              colors,
              settings.showDiacritics,
              () => settings.toggleDiacritics(!settings.showDiacritics),
            ),
          ),
          const SizedBox(height: 24),

          _buildDeveloperCard(colors, strings),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard(AppColors colors, AppLocalizations strings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.1),
            colors.accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.code_rounded,
                  color: colors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.get('developer'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.get('developer_name'),
                    style: TextStyle(
                      fontSize: 18,
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _launchWebsite(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: colors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.get('visit_website'),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: colors.accent,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://hashimhameem.site');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ur':
        return 'Urdu';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }

  void _showLanguageSelector(BuildContext context, SettingsService settings) {
    final colors = AppTheme.colors(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', 'en', settings),
            _buildLanguageOption(context, 'Urdu', 'ur', settings),
            _buildLanguageOption(context, 'العربية', 'ar', settings),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String name,
    String code,
    SettingsService settings,
  ) {
    final colors = AppTheme.colors(context);
    final isSelected = settings.locale.languageCode == code;

    return ListTile(
      title: Text(name, style: TextStyle(color: colors.text)),
      trailing: isSelected ? Icon(Icons.check, color: colors.accent) : null,
      onTap: () {
        settings.setLocale(Locale(code));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSettingItem(
    AppColors colors, {
    required String label,
    required String description,
    required Widget trailing,
    bool showBorder = true,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent, // Ensure hit test works
          border: showBorder
              ? Border(bottom: BorderSide(color: colors.border))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 16, color: colors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(AppColors colors, bool isOn, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: isOn ? colors.accent : colors.bgTertiary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/dictionary_source.dart';
import '../models/word.dart';
import 'result_screen.dart';
import '../utils/app_localizations.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isLoading = true;
  final Map<DictionarySource, List<Word>> _dictionaryWords = {};

  @override
  void initState() {
    super.initState();
    _loadDiscoveryData();
  }

  Future<void> _loadDiscoveryData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    try {
      // Fetch random words for all searchable dictionaries
      for (var source in DictionarySource.searchableDictionaries) {
        final words = await db.getRandomWords(source: source, limit: 3);
        _dictionaryWords[source] = words;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final settings = Provider.of<SettingsService>(context);
    final strings = settings.strings;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.accent))
            : RefreshIndicator(
                onRefresh: _loadDiscoveryData,
                color: colors.accent,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTokens.spacing20),
                  itemCount:
                      DictionarySource.searchableDictionaries.length +
                      1, // +1 for Header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          strings.get('discover'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      );
                    }

                    final source =
                        DictionarySource.searchableDictionaries[index - 1];
                    final words = _dictionaryWords[source] ?? [];

                    if (words.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          _getSourceTitle(source, strings),
                          _getSourceDescription(source, strings),
                          colors,
                        ),
                        const SizedBox(height: 16),
                        _buildWordList(words, colors, settings),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _getSourceTitle(DictionarySource source, AppLocalizations strings) {
    if (source == DictionarySource.all) {
      return strings.get('source_all');
    }
    return source.arabicName;
  }

  String _getSourceDescription(
    DictionarySource source,
    AppLocalizations strings,
  ) {
    switch (source) {
      case DictionarySource.ghoribulquran:
        return strings.get('desc_quran');
      case DictionarySource.lisanularab:
        return strings.get('desc_lisan');
      case DictionarySource.muashiroh:
        return strings.get('desc_muashiroh');
      case DictionarySource.wasith:
        return strings.get('desc_wasith');
      case DictionarySource.muhith:
        return strings.get('desc_muhith');
      case DictionarySource.shihah:
        return strings.get('desc_shihah');
      case DictionarySource.ghoni:
        return strings.get('desc_ghoni');
      default:
        return 'Arabic Dictionary';
    }
  }

  Widget _buildSectionHeader(String title, String subtitle, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildWordList(
    List<Word> words,
    AppColors colors,
    SettingsService settings,
  ) {
    return Column(
      children: words
          .map((word) => _buildDiscoveryCard(word, colors, settings))
          .toList(),
    );
  }

  Widget _buildDiscoveryCard(
    Word word,
    AppColors colors,
    SettingsService settings,
  ) {
    // Clean meaning preview
    final meaningPreview = word.meaning
        .replaceAll('<br>', ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .first
        .trim();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResultScreen(wordText: word.word, filterSource: word.source),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                word.word.substring(0, 1),
                style: AppTheme.arabicTextStyle(
                  context,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      settings.formatText(word.word),
                      style: AppTheme.arabicTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      meaningPreview,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

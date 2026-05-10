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
  Word? _wordOfTheDay;
  final Map<DictionarySource, List<Word>> _dictionaryWords = {};

  @override
  void initState() {
    super.initState();
    _loadDiscoveryData();
  }

  Future<void> _loadDiscoveryData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    try {
      // Kick off WOD + every per-source sample in parallel. Sequential
      // awaits would triple the time-to-paint on cold start.
      final wodFuture = db.getWordOfTheDay();
      final perSourceFutures = DictionarySource.searchableDictionaries.map(
        (source) => db
            .getRandomWords(source: source, limit: 3)
            .then((words) => MapEntry(source, words)),
      );

      final results = await Future.wait([wodFuture, ...perSourceFutures]);
      _wordOfTheDay = results.first as Word?;
      for (final entry in results.skip(1)) {
        if (entry is MapEntry<DictionarySource, List<Word>>) {
          _dictionaryWords[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reshuffleSource(DictionarySource source) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final fresh = await db.getRandomWords(source: source, limit: 3);
    if (!mounted) return;
    setState(() => _dictionaryWords[source] = fresh);
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
                      2, // Header + optional WOD
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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
                    if (index == 1) {
                      if (_wordOfTheDay == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _buildWodCard(
                          _wordOfTheDay!,
                          colors,
                          settings,
                          strings,
                        ),
                      );
                    }

                    final source =
                        DictionarySource.searchableDictionaries[index - 2];
                    final words = _dictionaryWords[source] ?? [];

                    if (words.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          _getSourceTitle(source, strings),
                          _getSourceDescription(source, strings),
                          colors,
                          onShuffle: () => _reshuffleSource(source),
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

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    AppColors colors, {
    VoidCallback? onShuffle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        if (onShuffle != null)
          IconButton(
            tooltip: 'Shuffle',
            icon: Icon(
              Icons.shuffle_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
            onPressed: onShuffle,
          ),
      ],
    );
  }

  Widget _buildWodCard(
    Word wod,
    AppColors colors,
    SettingsService settings,
    AppLocalizations strings,
  ) {
    final preview = wod.meaning
        .replaceAll('<br>', ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .first
        .trim();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            wordText: wod.word,
            filterSource: wod.source,
            initialWord: wod,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.accent,
              Color.lerp(colors.accent, Colors.black, 0.25)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTokens.radius20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('word_of_the_day'),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 14),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                settings.formatText(wod.word),
                style: AppTheme.arabicTextStyle(
                  context,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                preview,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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

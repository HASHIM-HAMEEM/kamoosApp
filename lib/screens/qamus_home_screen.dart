import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../services/search_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import 'result_screen.dart';

class QamusHomeScreen extends StatefulWidget {
  final VoidCallback onSettings;

  const QamusHomeScreen({super.key, required this.onSettings});

  @override
  State<QamusHomeScreen> createState() => _QamusHomeScreenState();
}

class _QamusHomeScreenState extends State<QamusHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  DictionarySource _selectedSource = DictionarySource.all;
  List<Word> _recentSearches = [];
  Word? _wordOfTheDay;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    // Load recent searches
    final recent = await dbService.getSearchHistory(limit: 5);

    // Load Word of the Day
    final wod = await dbService.getWordOfTheDay();

    if (mounted) {
      setState(() {
        _recentSearches = recent;
        _wordOfTheDay = wod;
      });
    }
  }

  // Helper to strip HTML tags from meaning
  String _getMeaningPreview(String meaning) {
    final clean = meaning.replaceAll(RegExp(r'<[^>]*>'), '');
    return clean.split('\n').first.trim();
  }

  void _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      // Save to history
      await dbService.addSearchHistory(query);

      // Navigate to result screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResultScreen(wordText: query, filterSource: _selectedSource),
          ),
        ).then((_) {
          // Reload recent searches when returning
          _loadData();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getSourceLabel(DictionarySource source, SettingsService settings) {
    if (source == DictionarySource.all) {
      return settings.strings.get('source_all');
    }
    return source.arabicName;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsService>(context);
    final strings = settings.strings;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spacing20,
                  AppTokens.spacing60,
                  AppTokens.spacing20,
                  AppTokens.spacing20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radius10,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'ع',
                            style: AppTheme.arabicTextStyle(
                              context,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strings.get('app_title'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                    // Actions
                    Row(
                      children: [
                        _buildIconButton(
                          context,
                          icon: Icons.settings,
                          onTap: widget.onSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spacing20,
                  vertical: AppTokens.spacing40,
                ),
                child: Column(
                  children: [
                    Text(
                      'Where Arabic Begins',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'حيث تبدأ العربية',
                      textAlign: TextAlign.center,
                      style: AppTheme.arabicTextStyle(
                        context,
                        fontSize: 28,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Search Bar
                    Container(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<Word>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.trim().isEmpty) {
                                    return const Iterable<Word>.empty();
                                  }
                                  final searchService =
                                      Provider.of<SearchService>(
                                        context,
                                        listen: false,
                                      );
                                  return await searchService
                                      .getSearchSuggestions(
                                        textEditingValue.text.trim(),
                                      );
                                },
                            displayStringForOption: (Word option) =>
                                option.word,
                            onSelected: (Word selection) {
                              _searchController.text = selection.word;
                              _handleSearch();
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  // Sync local controller with Autocomplete's controller
                                  if (_searchController !=
                                      textEditingController) {
                                    // We need to keep our _searchController in sync or use the one provided
                                    // Ideally, we should use the one provided by Autocomplete, but we have logic that uses _searchController
                                    // Let's just listen to changes
                                    textEditingController.addListener(() {
                                      if (_searchController.text !=
                                          textEditingController.text) {
                                        _searchController.text =
                                            textEditingController.text;
                                      }
                                    });
                                  }

                                  return Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Stack(
                                      children: [
                                        TextField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          onSubmitted: (_) => _handleSearch(),
                                          enabled: !_isLoading,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colors.text,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: strings.get(
                                              'search_hint',
                                            ),
                                            hintStyle: TextStyle(
                                              color: colors.textMuted,
                                            ),
                                            contentPadding: const EdgeInsets.only(
                                              left:
                                                  56, // Space for icons on left
                                              right:
                                                  20, // Padding for text on right
                                              top: 16,
                                              bottom: 16,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTokens.radius12,
                                                  ),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: colors.bgSecondary,
                                          ),
                                        ),
                                        Positioned(
                                          left: 16, // Icons on the left now
                                          top: 0,
                                          bottom: 0,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: _isLoading
                                                    ? null
                                                    : _handleSearch,
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: _isLoading
                                                        ? colors.textMuted
                                                        : colors.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTokens.radius10,
                                                        ),
                                                  ),
                                                  child: _isLoading
                                                      ? const Padding(
                                                          padding:
                                                              EdgeInsets.all(8),
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.search,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                ),
                                              ),
                                              if (textEditingController
                                                  .text
                                                  .isNotEmpty)
                                                GestureDetector(
                                                  onTap: () {
                                                    textEditingController
                                                        .clear();
                                                    _searchController.clear();
                                                    setState(() {});
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.close,
                                                      color: colors.textMuted,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.radius12,
                                  ),
                                  color: colors.cardBg,
                                  child: Container(
                                    width: constraints.maxWidth,
                                    constraints: const BoxConstraints(
                                      maxHeight: 300,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final Word option = options
                                                .elementAt(index);
                                            return ListTile(
                                              title: Text(
                                                option.word,
                                                style: AppTheme.arabicTextStyle(
                                                  context,
                                                  fontSize: 16,
                                                  color: colors.text,
                                                ),
                                              ),
                                              subtitle: Text(
                                                option.source?.arabicName ?? '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          strings.get('search_try'),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textMuted,
                          ),
                        ),
                        ...['كتاب', 'مدرسة', 'سماء'].map(
                          (word) => GestureDetector(
                            onTap: () {
                              _searchController.text = word;
                              _handleSearch();
                            },
                            child: Text(
                              ' $word,',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          strings.get('or_any_word'),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Source Chips (Scrollable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [
                              DictionarySource.all,
                              ...DictionarySource.searchableDictionaries,
                            ].map((source) {
                              final isActive = _selectedSource == source;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedSource = source),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? colors.accentLight
                                          : colors.bgSecondary,
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.radius20,
                                      ),
                                      border: Border.all(
                                        color: isActive
                                            ? colors.accent
                                            : colors.border,
                                      ),
                                    ),
                                    child: Text(
                                      _getSourceLabel(source, settings),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isActive
                                            ? colors.accent
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Word of the Day
              if (_wordOfTheDay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spacing20,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ResultScreen(
                            wordText: _wordOfTheDay!.word,
                            initialWord: _wordOfTheDay,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.accent,
                            Color.lerp(
                              colors.accent,
                              Colors.black,
                              isDark ? 0.3 : 0.2,
                            )!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppTokens.radius20),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'WORD OF THE DAY',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  _wordOfTheDay!.word,
                                  style: AppTheme.arabicTextStyle(
                                    context,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  _getMeaningPreview(_wordOfTheDay!.meaning),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Text(
                              _wordOfTheDay!.word.substring(0, 1),
                              style: AppTheme.arabicTextStyle(
                                context,
                                fontSize: 120,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Recent Searches
              if (_recentSearches.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppTokens.spacing20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENT SEARCHES',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.clear_all, size: 20),
                            color: colors.textMuted,
                            onPressed: () async {
                              final dbService = Provider.of<DatabaseService>(
                                context,
                                listen: false,
                              );
                              await dbService.clearSearchHistory();
                              setState(() {
                                _recentSearches = [];
                              });
                            },
                            tooltip: 'Clear all',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._recentSearches
                          .take(5)
                          .map((word) => _buildThreadCard(context, word: word)),
                    ],
                  ),
                ),

              const SizedBox(height: 100), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(BuildContext context, {required Word word}) {
    final colors = AppTheme.colors(context);

    // Extract first line of meaning for preview
    final meaningPreview = word.meaning
        .split('\n')
        .first
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    final preview = meaningPreview.length > 60
        ? '${meaningPreview.substring(0, 60)}...'
        : meaningPreview;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              wordText: word.word,
              filterSource: word.source,
              initialWord: word,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                word.word,
                style: AppTheme.arabicTextStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                preview,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.book, size: 14, color: colors.textMuted),
                const SizedBox(width: 8),
                Text(
                  word.source?.arabicName ?? 'Dictionary',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = AppTheme.colors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.bgSecondary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: colors.textSecondary, size: 20),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

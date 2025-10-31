import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../utils/text_utils.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../services/search_service.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class WordDetailScreen extends StatefulWidget {
  final String wordText;
  final Word? initialWord;
  final DictionarySource? filterSource;

  const WordDetailScreen({super.key, required this.wordText, this.initialWord, this.filterSource});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  Word? _word;
  List<Word> _aiEntries = [];
  List<Word> _dictionaryEntries = [];
  bool _isLoading = true;
  bool _isLoadingAI = false; // Track AI loading separately
  String? _errorMessage;
  DictionarySource? _filterSource;

  // Track which entries are expanded (by default AI is expanded, dictionaries collapsed)
  final Map<String, bool> _expandedEntries = {};

  @override
  void initState() {
    super.initState();
    _word = widget.initialWord;
    _filterSource = widget.filterSource;
    _loadEntries(widget.wordText);
  }

  Future<void> _loadEntries(String wordText) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isLoadingAI = false;
        _errorMessage = null;
        _aiEntries = [];
        _dictionaryEntries = [];
      });
    }

    try {
      final searchService = Provider.of<SearchService>(context, listen: false);
      final api = Provider.of<ApiService?>(context, listen: false);

      // Step 1: Load dictionary entries FIRST (fast, local database)
      final dictEntries = await searchService.getDictionaryEntries(wordText, source: _filterSource);

      if (!mounted) return;

      // Step 2: Show dictionary results immediately
      if (dictEntries.isNotEmpty) {
        setState(() {
          _dictionaryEntries = dictEntries;
          _word = _word ?? dictEntries.first;
          _isLoading = false; // Stop main loading, show dictionary results
          _isLoadingAI = true; // Start AI loading indicator
        });

        // Step 3: Load AI results in background (slower, network call)
        if (api != null) {
          _loadAIResultsInBackground(wordText, api);
        } else {
          // No API available, stop AI loading
          if (mounted) {
            setState(() {
              _isLoadingAI = false;
            });
          }
        }
      } else {
        // No dictionary results, wait for AI results
        setState(() {
          _isLoading = true; // Keep loading
          _isLoadingAI = true;
        });

        if (api != null) {
          final aiResult = await api.getWordMeaning(wordText);
          if (!mounted) return;

          if (aiResult != null) {
            setState(() {
              _aiEntries = [aiResult];
              _word = _word ?? aiResult;
              _isLoading = false;
              _isLoadingAI = false;
            });
          } else {
            // No results at all
            setState(() {
              _errorMessage = 'لم يتم العثور على معنى لهذه الكلمة';
              _isLoading = false;
              _isLoadingAI = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'لم يتم العثور على معنى لهذه الكلمة';
            _isLoading = false;
            _isLoadingAI = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء البحث: ${e.toString()}';
          _isLoading = false;
          _isLoadingAI = false;
        });
      }
    }
  }

  /// Load AI results in background and update when ready
  Future<void> _loadAIResultsInBackground(String wordText, ApiService api) async {
    try {
      final aiResult = await api.getWordMeaning(wordText);

      if (!mounted) return;

      if (aiResult != null) {
        setState(() {
          _aiEntries = [aiResult];
          _word = _word ?? aiResult;
          _isLoadingAI = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAI = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Background AI loading failed: $e');
      if (mounted) {
        setState(() {
          _isLoadingAI = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _word != null
                    ? _buildWordDetails()
                    : _buildNotFoundView(),
      ),
    );
  }

  // Build an expandable entry section for each dictionary/AI result
  Widget _buildExpandableEntry(Word entry, {required bool isAI}) {
    final theme = Theme.of(context);

    // Create unique key for this entry
    final entryKey = isAI ? 'ai_entry' : '${entry.source?.tableName ?? 'unknown'}_${entry.word}';

    // AI entries are always expanded, dictionary entries start collapsed
    final isExpanded = _expandedEntries.putIfAbsent(entryKey, () => isAI);

    // Build source label
    String sourceLabel;
    if (isAI) {
      sourceLabel = 'ذكاء اصطناعي';
    } else {
      sourceLabel = entry.source?.arabicName ?? 'مجهول';
    }

    // Build metadata (root word)
    String? rootInfo;
    if (entry.rootWord != null && entry.rootWord!.trim().isNotEmpty) {
      rootInfo = 'الجذر: ${entry.rootWord!}';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (tappable to expand/collapse)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12),
                bottom: isExpanded ? Radius.zero : Radius.circular(12),
              ),
              onTap: () {
                setState(() {
                  _expandedEntries[entryKey] = !isExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sourceLabel,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (rootInfo != null) ...[
                            SizedBox(height: 4),
                            Text(
                              rootInfo,
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content (visible when expanded)
          if (isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                  SizedBox(height: 16),

                  // Quran verse if applicable
                  if (entry.source == DictionarySource.ghoribulquran && entry.surahNumber != null && entry.ayahNumber != null)
                    FutureBuilder<Map<String, String>?>(
                      future: Provider.of<DatabaseService>(context, listen: false)
                          .getQuranVerse(entry.surahNumber!, entry.ayahNumber!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return SizedBox.shrink();
                        final verse = snapshot.data!;
                        return Container(
                          margin: EdgeInsets.only(bottom: 16.0),
                          padding: EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verse['arab'] ?? '',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontSize: 15.0, height: 1.6, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                              ),
                              if ((verse['nama_surat'] ?? '').isNotEmpty) ...[
                                SizedBox(height: 10),
                                Text(
                                  'سورة ${verse['nama_surat']} (${entry.surahNumber}:${entry.ayahNumber})',
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(fontSize: 12.0, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ]
                            ],
                          ),
                        );
                      },
                    ),

                  // Meaning content
                  FutureBuilder<List<String>>(
                    future: compute(splitMeaningIsolate, entry.meaning),
                    builder: (context, snapshot) {
                      final parts = snapshot.data ?? const <String>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in parts)
                            Padding(
                              padding: EdgeInsets.only(bottom: 12.0),
                              child: Text(
                                p,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  height: 1.6,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadEntries(widget.wordText),
              child: Text('أعد المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            SizedBox(height: 16),
            Text(
              'لم يتم العثور على الكلمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'الكلمة التي تبحث عنها غير متوفرة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildWordDetails() {
    final theme = Theme.of(context);

    // Build metadata
    final List<String> metadata = [];
    if (_word!.source != null) {
      metadata.add(_word!.source!.arabicName);
    }
    if (_word!.rootWord != null) {
      metadata.add('الجذر: ${_word!.rootWord!}');
    }

    return CustomScrollView(
      slivers: [
        // Simple app bar
        SliverAppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          floating: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.copy_all, size: 20),
              onPressed: () {
                if (_word != null) {
                  Clipboard.setData(ClipboardData(text: _word!.word));
                }
              },
            ),
          ],
        ),

        // Word header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _word!.word,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (metadata.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    metadata.join(' • '),
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // AI Loading indicator (shown when AI is being fetched in background)
        if (_isLoadingAI && _aiEntries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
              child: _buildAILoadingIndicator(),
            ),
          ),

        // Offline indicator (shown when dictionary results exist but no AI results and not loading)
        if (!_isLoadingAI && _dictionaryEntries.isNotEmpty && _aiEntries.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
              child: _buildOfflineIndicator(),
            ),
          ),

        // Content section
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render AI results first (always expanded)
                for (final entry in _aiEntries) _buildExpandableEntry(entry, isAI: true),

                // Then render dictionary results (collapsible)
                for (final entry in _dictionaryEntries) _buildExpandableEntry(entry, isAI: false),

                if (_word!.meaningEn != null && _word!.meaningEn!.trim().isNotEmpty)
                  _buildSectionWithIcon(
                    title: 'المعنى بالإنجليزية',
                    content: _word!.meaningEn!,
                  ),

                if (_word!.meaningUr != null && _word!.meaningUr!.trim().isNotEmpty)
                  _buildSectionWithIcon(
                    title: 'المعنى بالأردية',
                    content: _word!.meaningUr!,
                  ),

                if (_word!.history != null)
                  _buildSectionWithIcon(
                    title: 'الأصل والتطور',
                    content: _word!.history!,
                  ),

                if (_word!.examples != null)
                  _buildSectionWithIcon(
                    title: 'أمثلة',
                    content: _word!.examples!,
                  ),

                if (_word!.relatedWords != null)
                  _buildSectionWithIcon(
                    title: 'كلمات مرتبطة',
                    content: _word!.relatedWords!,
                  ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAILoadingIndicator() {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'جاري تحميل نتائج الذكاء الاصطناعي...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد نتائج من الذكاء الاصطناعي (غير متصل)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWithIcon({
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 12),
            Text(
              content,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 15.0,
                height: 1.6,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../services/search_service.dart';
import '../widgets/dictionary_card.dart';
import '../services/settings_service.dart';

class ResultScreen extends StatefulWidget {
  final String wordText;
  final DictionarySource? filterSource;
  final Word? initialWord;

  const ResultScreen({
    super.key,
    required this.wordText,
    this.filterSource,
    this.initialWord,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Word> _results = [];
  bool _isLoading = true;
  bool _noLocalMatch = false;
  bool _aiFailed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _aiFailed = false;
      _noLocalMatch = false;
    });

    final searchService = Provider.of<SearchService>(context, listen: false);

    // 1. Pull every local dictionary entry in parallel with kicking off the
    // AI lookup (which itself hits an in-memory -> persisted -> network
    // ladder inside SearchService).
    final dbFuture = searchService.getDictionaryEntries(
      widget.wordText,
      source: widget.filterSource,
    );
    final aiFuture = searchService.searchWordDetailed(widget.wordText);

    final localResults = await dbFuture.catchError((e) {
      debugPrint('Local lookup failed: $e');
      return <Word>[];
    });

    if (!mounted) return;

    final combined = <Word>[];
    if (widget.initialWord != null) {
      final initial = widget.initialWord!;
      final exists = localResults.any(
        (w) =>
            w.word == initial.word &&
            w.meaning == initial.meaning &&
            w.source == initial.source,
      );
      if (!exists) combined.add(initial);
    }
    combined.addAll(localResults);

    setState(() {
      _results = combined;
      _noLocalMatch = combined.isEmpty;
      _isLoading = false;
    });

    // 2. Await the AI leg and splice its answer in (or show the offline
    // banner). Only surface "AI failed" when we also have no local rows —
    // if the local lexicon already answered, a missing AI bonus is not
    // worth interrupting the user with a banner.
    final outcome = await aiFuture;
    if (!mounted) return;

    if (outcome.word != null) {
      final ai = outcome.word!;
      final alreadyShown = _results.any(
        (w) =>
            w.word == ai.word &&
            w.meaning == ai.meaning &&
            w.source == ai.source,
      );
      if (!alreadyShown) {
        setState(() {
          _results = [ai, ..._results];
          _noLocalMatch = false;
          _aiFailed = false;
        });
      }
    } else if (outcome.aiFailed && _results.isEmpty) {
      setState(() => _aiFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<SettingsService>(
          builder: (context, settings, _) => Text(
            settings.strings.get('results'),
            style: TextStyle(color: colors.text, fontSize: 18),
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }

    final settings = Provider.of<SettingsService>(context, listen: false);

    if (_noLocalMatch && _results.isEmpty && !_aiFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              settings.strings.get('no_results'),
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_aiFailed) _buildOfflineBanner(colors, settings),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<SettingsService>(
                  builder: (context, settings, _) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          settings.formatText(widget.wordText),
                          style: AppTheme.arabicTextStyle(
                            context,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                ..._results.map((word) {
                  final isAi = word.source == null;
                  return DictionaryCard(word: word, isAi: isAi);
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBanner(AppColors colors, SettingsService settings) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTokens.spacing20,
        AppTokens.spacing20,
        AppTokens.spacing20,
        0,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              settings.strings.get('ai_offline_banner'),
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _loadData,
            style: TextButton.styleFrom(
              foregroundColor: colors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(settings.strings.get('retry')),
          ),
        ],
      ),
    );
  }
}

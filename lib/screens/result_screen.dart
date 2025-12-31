import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../services/search_service.dart';
import '../services/api_service.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final searchService = Provider.of<SearchService>(context, listen: false);
    final apiService = Provider.of<ApiService?>(context, listen: false);

    final dbFuture = searchService.getDictionaryEntries(
      widget.wordText,
      source: widget.filterSource,
    );

    final Future<Word?>? aiFuture =
        apiService?.getWordMeaning(widget.wordText);

    List<Word> localResults = [];
    String? loadError;
    try {
      localResults = await dbFuture;
    } catch (e) {
      loadError = 'Error: $e';
    }

    if (!mounted) return;

    final combinedResults = <Word>[];
    if (widget.initialWord != null) {
      final initial = widget.initialWord!;
      final exists = localResults.any(
        (w) =>
            w.word == initial.word &&
            w.meaning == initial.meaning &&
            w.source == initial.source,
      );
      if (!exists) {
        combinedResults.add(initial);
      }
    }
    combinedResults.addAll(localResults);

    setState(() {
      if (combinedResults.isNotEmpty) {
        _results = combinedResults;
        _errorMessage = null;
      } else {
        _errorMessage = loadError ?? 'No results found';
      }
      _isLoading = false;
    });

    if (aiFuture != null) {
      try {
        final aiResult = await aiFuture;
        if (!mounted || aiResult == null) return;
        final alreadyShown = _results.any(
          (w) =>
              w.word == aiResult.word &&
              w.meaning == aiResult.meaning &&
              w.source == aiResult.source,
        );
        if (!alreadyShown) {
          setState(() {
            _results = [aiResult, ..._results];
            _errorMessage = null;
          });
        }
      } catch (e) {
        debugPrint('AI fetch failed: $e');
      }
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
        title: Text(
          'Results',
          style: TextStyle(color: colors.text, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Word Header
          Consumer<SettingsService>(
            builder: (context, settings, _) {
              return Center(
                child: Text(
                  settings.formatText(widget.wordText),
                  style: AppTheme.arabicTextStyle(
                    context,
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Results List
          ..._results.map((word) {
            // Check if it's an AI result (source is null or special)
            // Ideally we flag this better, but for now:
            final isAi = word.source == null;
            return DictionaryCard(word: word, isAi: isAi);
          }),

          // Bottom padding
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

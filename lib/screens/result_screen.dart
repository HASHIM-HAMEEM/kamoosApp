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

    try {
      final searchService = Provider.of<SearchService>(context, listen: false);
      final apiService = Provider.of<ApiService?>(context, listen: false);

      // Start both fetches in parallel
      final dbFuture = searchService.getDictionaryEntries(
        widget.wordText,
        source: widget.filterSource,
      );

      Future<Word?>? aiFuture;
      if (apiService != null) {
        // Only fetch AI if we have the service
        // We can also check if we already have it in cache via SearchService,
        // but SearchService.searchWord does that.
        // Here we want explicit control.
        // Let's use SearchService's searchWord for AI to leverage cache,
        // but we need to force it to ONLY return AI if we want strict separation?
        // Actually, apiService.getWordMeaning is direct.
        aiFuture = apiService.getWordMeaning(widget.wordText);
      }

      // Wait for both
      final List<Word> localResults = await dbFuture;
      final Word? aiResult = aiFuture != null ? await aiFuture : null;

      // Combine results: AI first, then Local
      final List<Word> combinedResults = [];

      if (aiResult != null) {
        combinedResults.add(aiResult);
      }

      combinedResults.addAll(localResults);

      if (mounted) {
        setState(() {
          if (combinedResults.isNotEmpty) {
            _results = combinedResults;
          } else {
            _errorMessage = 'No results found';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
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

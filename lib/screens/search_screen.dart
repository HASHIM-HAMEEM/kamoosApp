import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../services/search_service.dart';
import 'word_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Word> _searchSuggestions = [];
  DictionarySource _selectedDictionary = DictionarySource.all;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilter();
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordDetailScreen(
          wordText: q,
          initialWord: null,
          filterSource: _selectedDictionary,
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (value.length > 1) {
        final searchService = Provider.of<SearchService>(context, listen: false);
        final suggestions = await searchService.getSearchSuggestions(value, source: _selectedDictionary);
        if (!mounted) return;
        setState(() {
          _searchSuggestions = suggestions;
        });
      } else {
        setState(() {
          _searchSuggestions = [];
        });
      }
    });
  }

  Future<void> _loadFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('filter_source');
    if (t == null) return;
    final match = DictionarySource.values.firstWhere(
      (s) => s.tableName == t,
      orElse: () => DictionarySource.all,
    );
    if (mounted) {
      setState(() {
        _selectedDictionary = match;
      });
    }
  }

  Future<void> _saveFilter(DictionarySource src) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filter_source', src.tableName);
  }

  void _showDictionaryFilter() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'اختر المعجم',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                ...[
                  DictionarySource.all,
                  ...DictionarySource.searchableDictionaries,
                ].map((src) {
                  final isSelected = _selectedDictionary == src;
                  return InkWell(
                    onTap: () async {
                      setState(() {
                        _selectedDictionary = src;
                      });
                      await _saveFilter(src);
                      final text = _searchController.text;
                      if (text.length > 1) {
                        _onSearchChanged(text);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.outline.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              src.arabicName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        minimum: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          children: [
            // App title
            Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 40.0),
              child: Text(
                'قاموس',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Search bar with filter button
            Container(
              constraints: BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  // Filter button
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    child: Material(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showDictionaryFilter,
                        child: Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.menu_book,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      onSubmitted: _performSearch,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن كلمة...',
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Current filter indicator (optional, small)
            if (_selectedDictionary != DictionarySource.all)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedDictionary.arabicName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              setState(() {
                                _selectedDictionary = DictionarySource.all;
                              });
                              await _saveFilter(DictionarySource.all);
                              final text = _searchController.text;
                              if (text.length > 1) {
                                _onSearchChanged(text);
                              }
                            },
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24.0),
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildWelcomeView()
                  : _buildSuggestionsList(),
            ),
            
            // Footer text
            Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.ltr,
                children: [
                  Text(
                    'fin',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: theme.brightness == Brightness.dark 
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '.',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                      color: theme.brightness == Brightness.dark 
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '❤️',
                    style: TextStyle(
                      fontSize: 10.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            SizedBox(height: 16),
            Text(
              'ابحث عن كلمة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    final theme = Theme.of(context);
    if (_searchSuggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              SizedBox(height: 16),
              Text(
                'لا توجد نتائج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _searchSuggestions.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final word = _searchSuggestions[index];
        return _buildWordCard(word, () => _performSearch(word.word));
      },
    );
  }

  Widget _buildWordCard(Word word, VoidCallback onTap) {
    final preview = _formatMeaningPreview(word.meaning);
    final theme = Theme.of(context);

    // Build source and root info
    final List<String> metadata = [];
    if (word.source != null) {
      metadata.add(word.source!.arabicName);
    } else {
      metadata.add('ذكاء اصطناعي');
    }
    if (word.rootWord != null && word.rootWord!.trim().isNotEmpty) {
      metadata.add('الجذر: ${word.rootWord!}');
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (metadata.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    metadata.join(' • '),
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Text(
                  preview.length > 100
                      ? '${preview.substring(0, 100)}...'
                      : preview,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14.0,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMeaningPreview(String meaning) {
    final withBreaks = meaning.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final withoutTags = withBreaks.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalizedLines = withoutTags.split('\n').map((line) {
      return line.replaceAll(RegExp(r'\s+'), ' ').trim();
    }).where((line) => line.isNotEmpty).join('\n');
    if (normalizedLines.isEmpty) {
      return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return normalizedLines;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}

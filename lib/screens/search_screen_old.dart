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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Important for handling keyboard
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
                // App title and search header
                Container(
                  margin: EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    children: [
                      Text(
                        'القاموس العربي',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ابحث عن الكلمات وتعلم معانيها',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Dictionary filter dropdown
                Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Text(
                              'المعاجم',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<DictionarySource>(
                                value: _selectedDictionary,
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
                                borderRadius: BorderRadius.circular(12),
                                items: [
                                  DictionarySource.all,
                                  ...DictionarySource.searchableDictionaries,
                                ].map((src) {
                                  return DropdownMenuItem<DictionarySource>(
                                    value: src,
                                    child: Text(
                                      src.arabicName,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (src) async {
                                  if (src == null) return;
                                  setState(() {
                                    _selectedDictionary = src;
                                  });
                                  await _saveFilter(src);
                                  final text = _searchController.text;
                                  if (text.length > 1) {
                                    _onSearchChanged(text);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Search bar with anchored dropdown suggestions
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: RawAutocomplete<Word>(
                    focusNode: _searchFocus,
                    textEditingController: _searchController,
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.trim().length <= 1) {
                        return const Iterable<Word>.empty();
                      }
                      // Return current async-fetched suggestions synchronously
                      return _searchSuggestions.where((w) => w.word.contains(value.text));
                    },
                    displayStringForOption: (w) => w.word,
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 18.0,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن كلمة...',
                          hintTextDirection: TextDirection.rtl,
                          prefixIcon: Container(
                            padding: EdgeInsets.all(16.0),
                            child: Icon(
                              Icons.search,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final opts = options.toList();
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Material(
                          elevation: 6,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  spreadRadius: 0,
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 320,
                                minWidth: MediaQuery.of(context).size.width - 32,
                                maxWidth: 400,
                              ),
                              child: ListView.separated(
                                padding: EdgeInsets.all(12.0),
                                itemCount: opts.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                                itemBuilder: (context, index) {
                                  final word = opts[index];
                                  return _buildWordCard(word, () => onSelected(word));
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (Word w) {
                      _performSearch(w.word);
                    },
                  ),
                ),
                
                SizedBox(height: 16.0),
                Expanded(
                  child: _searchController.text.isEmpty
                      ? _buildWelcomeView()
                      : _buildSuggestionsList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.book_outlined,
                size: 60,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'ابدأ بالبحث',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'ابحث عن الكلمات العربية لتعلم معانيها وتصريفاتها',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'نصائح للبحث',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• اكتب الكلمة أو الجذر للحصول على نتائج دقيقة\n• استخدم خانة التصفية لتحديد المعجم الذي تريده',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_searchSuggestions.isEmpty) {
      return Center(
        child: Text(
          'لا توجد اقتراحات حالياً',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(top: 8.0),
      itemCount: _searchSuggestions.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final word = _searchSuggestions[index];
        return _buildWordCard(word, () => _performSearch(word.word));
      },
    );
  }

  Widget _buildWordCard(Word word, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
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
                    fontSize: 20.0,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (word.source != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green[700]!.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          word.source!.arabicName,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.indigo[700]!.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ذكاء اصطناعي',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo[700],
                          ),
                        ),
                      ),
                    if (word.rootWord != null && word.rootWord!.trim().isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'الجذر: ${word.rootWord!}',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  word.meaning.length > 100
                      ? '${word.meaning.substring(0, 100)}...'
                      : word.meaning,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}
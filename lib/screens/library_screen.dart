import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';

import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/word.dart';
import 'result_screen.dart';
import 'collection_detail_screen.dart';
import '../utils/app_localizations.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Word> _historyWords = [];
  List<Word> _favoriteWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    final history = await dbService.getSearchHistory(limit: 20);
    final favorites = await dbService.getFavorites();

    if (mounted) {
      setState(() {
        _historyWords = history;
        _favoriteWords = favorites;
        _isLoading = false;
      });
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
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppTokens.spacing20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.get('library'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppTokens.spacing20,
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colors.border.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: UnderlineTabIndicator(
                        borderSide: BorderSide(
                          color: colors.accent,
                          width: 3,
                        ),
                        insets: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelColor: colors.accent,
                      unselectedLabelColor: colors.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      tabs: [
                        Tab(text: strings.get('history')),
                        Tab(text: strings.get('favorites')),
                        Tab(text: strings.get('collections')),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.accent),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildHistoryTab(colors, strings),
                        _buildFavoritesTab(colors, strings),
                        _buildCollectionsTab(colors, strings),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(AppColors colors, AppLocalizations strings) {
    if (_historyWords.isEmpty) {
      return _buildEmptyState(
        strings.get('no_collections'),
        Icons.history,
        colors,
      ); // Using generic empty message or specific if available
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing20),
      itemCount: _historyWords.length,
      itemBuilder: (context, index) {
        final word = _historyWords[index];
        return _buildWordCard(word, colors);
      },
    );
  }

  Widget _buildFavoritesTab(AppColors colors, AppLocalizations strings) {
    if (_favoriteWords.isEmpty) {
      return _buildEmptyState(
        strings.get('no_collections'),
        Icons.favorite_border,
        colors,
      ); // Reuse empty message for now or add specific
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spacing20),
      itemCount: _favoriteWords.length,
      itemBuilder: (context, index) {
        final word = _favoriteWords[index];
        return _buildWordCard(word, colors, showFavorite: true);
      },
    );
  }

  Widget _buildCollectionsTab(AppColors colors, AppLocalizations strings) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DatabaseService>(
        context,
        listen: false,
      ).getCollections(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colors.accent));
        }

        final collections = snapshot.data ?? [];

        if (collections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 64, color: colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  strings.get('no_collections'),
                  style: TextStyle(fontSize: 16, color: colors.textSecondary),
                ),
                const SizedBox(height: 24),
                _buildCreateCollectionButton(colors, strings),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTokens.spacing20),
              child: _buildCreateCollectionButton(
                colors,
                strings,
                isSmall: true,
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spacing20,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  return _buildCollectionCard(collection, colors);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateCollectionButton(
    AppColors colors,
    AppLocalizations strings, {
    bool isSmall = false,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _showCreateCollectionDialog(colors, strings),
      icon: const Icon(Icons.add),
      label: Text(strings.get('create_collection')),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 16 : 24,
          vertical: isSmall ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(
    Map<String, dynamic> collection,
    AppColors colors,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CollectionDetailScreen(
              collectionId: collection['id'],
              collectionName: collection['name'],
            ),
          ),
        ).then((_) => setState(() {})); // Refresh on return
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.folder, size: 32, color: colors.accent),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${collection['count']} items',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCollectionDialog(AppColors colors, AppLocalizations strings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardBg,
        title: Text(
          strings.get('create_collection'),
          style: TextStyle(color: colors.text),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: colors.text),
          decoration: InputDecoration(
            hintText: strings.get('collection_name'),
            hintStyle: TextStyle(color: colors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.accent),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              strings.get('cancel'),
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await Provider.of<DatabaseService>(
                  context,
                  listen: false,
                ).createCollection(controller.text.trim());
                if (mounted && context.mounted) {
                  Navigator.pop(context);
                  setState(() {}); // Refresh
                }
              }
            },
            child: Text(
              strings.get('create'),
              style: TextStyle(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(
    Word word,
    AppColors colors, {
    bool showFavorite = false,
  }) {
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
            builder: (context) =>
                ResultScreen(wordText: word.word, filterSource: word.source),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Consumer<SettingsService>(
                    builder: (context, settings, _) {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          settings.formatText(word.word),
                          style: AppTheme.arabicTextStyle(
                            context,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (showFavorite)
                  Icon(Icons.favorite, size: 16, color: colors.accent),
              ],
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

  Widget _buildEmptyState(String message, IconData icon, AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

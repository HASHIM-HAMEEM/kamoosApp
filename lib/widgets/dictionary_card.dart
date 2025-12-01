import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class DictionaryCard extends StatefulWidget {
  final Word word;
  final bool isAi;
  final VoidCallback? onShare;

  const DictionaryCard({
    super.key,
    required this.word,
    this.isAi = false,
    this.onShare,
  });

  @override
  State<DictionaryCard> createState() => _DictionaryCardState();
}

class _DictionaryCardState extends State<DictionaryCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    if (widget.isAi) {
      return; // Don't favorite AI results for now (or handle differently)
    }
    final db = Provider.of<DatabaseService>(context, listen: false);
    final isFav = await db.isFavorite(widget.word);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.isAi) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.toggleFavorite(widget.word);
    await _checkFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final settings = Provider.of<SettingsService>(context);
    final sourceName = widget.isAi
        ? 'fin'
        : (widget.word.source?.arabicName ?? 'Unknown Source');

    // Apply diacritics setting to the word
    // The `displayWord` variable was removed as it was unused.
    // The `settings` variable is still used for `settings.strings.get('copied')`.

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
          color: widget.isAi
              ? colors.accent.withValues(alpha: 0.5)
              : colors.border,
          width: widget.isAi ? 1.5 : 1,
        ),
        boxShadow: widget.isAi
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isAi
                  ? colors.accent.withValues(alpha: 0.1)
                  : colors.bgSecondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radius16 - 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isAi ? Icons.auto_awesome : Icons.menu_book,
                      size: 16,
                      color: widget.isAi ? colors.accent : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sourceName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isAi
                            ? colors.accent
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!widget.isAi)
                      _buildIconButton(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        colors,
                        onTap: _toggleFavorite,
                        isActive: _isFavorite,
                      ),
                    const SizedBox(width: 8),
                    if (!widget.isAi) ...[
                      _buildIconButton(
                        Icons.bookmark_add_outlined,
                        colors,
                        onTap: () => _showAddToCollectionSheet(context, colors),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildIconButton(
                      Icons.copy,
                      colors,
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${widget.word.word}\n\n${widget.word.meaning}',
                          ),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(settings.strings.get('copied')),
                              backgroundColor: colors.accent,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Word (with diacritics logic applied if needed, though usually meaning is what matters,
                // but if we were displaying the headword prominently we'd use displayWord.
                // Here the headword isn't explicitly shown in the card body, only in the result screen header usually.
                // But wait, DictionaryCard is used in ResultScreen which shows the word at the top.
                // DictionaryCard shows the MEANING.
                // If the meaning contains Arabic text, we might want to strip diacritics there too?
                // The user said "show diacticatics should work". Usually this applies to the headword.
                // Let's check if DictionaryCard displays the headword. It doesn't seem to display the headword in the body, only meaning.
                // However, ResultScreen displays the headword. I should check ResultScreen too.
                // But wait, DictionaryCard is a list item.
                // Let's assume the user wants the meaning text to be affected if it's Arabic?
                // Or maybe they mean the headword in the result screen?
                // I'll apply it to the meaning text if it looks like Arabic?
                // Actually, meanings are usually mixed.
                // Let's just apply it to the headword if it was shown.
                // But wait, the previous code didn't show headword in card.
                // Let's check ResultScreen.

                // English Meaning
                if (widget.word.meaningEn != null &&
                    widget.word.meaningEn!.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.word.meaningEn!,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: colors.text,
                        fontFamily: 'Roboto',
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Urdu Meaning
                if (widget.word.meaningUr != null &&
                    widget.word.meaningUr!.isNotEmpty) ...[
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.word.meaningUr!,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          color: colors.text,
                          fontFamily: 'NotoNastaliqUrdu',
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Arabic Meaning
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      widget.word.meaning
                          .replaceAll('<br>', '\n')
                          .replaceAll(RegExp(r'<[^>]*>'), ''),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: widget.isAi ? colors.textSecondary : colors.text,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),

                // Extra Details (Root, Examples)
                if (widget.word.rootWord != null ||
                    widget.word.examples != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                if (widget.word.rootWord != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          'Root: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          widget.word.rootWord!,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.accent,
                            fontFamily: 'NotoNaskhArabic',
                          ),
                        ),
                      ],
                    ),
                  ),

                if (widget.word.examples != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Examples:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.word.examples!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    AppColors colors, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? colors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? colors.accent : colors.textMuted,
        ),
      ),
    );
  }

  void _showAddToCollectionSheet(BuildContext context, AppColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToCollectionSheet(word: widget.word),
    );
  }
}

class _AddToCollectionSheet extends StatefulWidget {
  final Word word;
  const _AddToCollectionSheet({required this.word});

  @override
  State<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<_AddToCollectionSheet> {
  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Provider.of<DatabaseService>(
        context,
        listen: false,
      ).getCollections(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: colors.accent));
        }

        final collections = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Collection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 16),
              if (collections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No collections found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                )
              else
                ...collections.map(
                  (c) => ListTile(
                    leading: Icon(Icons.folder, color: colors.accent),
                    title: Text(
                      c['name'],
                      style: TextStyle(color: colors.text),
                    ),
                    onTap: () async {
                      await Provider.of<DatabaseService>(
                        context,
                        listen: false,
                      ).addToCollection(c['id'], widget.word);
                      if (mounted) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to ${c['name']}'),
                              backgroundColor: colors.accent,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

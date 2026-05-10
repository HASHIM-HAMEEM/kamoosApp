import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/word.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/tokens.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../utils/text_clean.dart';

/// A dictionary entry. The card is intentionally quiet — a 3px accent
/// rule on the leading edge and a small chip identify the source without
/// the heavy coloured banner the v1 card had, which read more like a
/// chat bubble than a reference entry.
class DictionaryCard extends StatefulWidget {
  final Word word;
  final bool isAi;

  const DictionaryCard({super.key, required this.word, this.isAi = false});

  @override
  State<DictionaryCard> createState() => _DictionaryCardState();
}

class _DictionaryCardState extends State<DictionaryCard> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _refreshFavorite();
  }

  Future<void> _refreshFavorite() async {
    if (widget.isAi) return; // AI rows aren't favoritable yet
    final db = Provider.of<DatabaseService>(context, listen: false);
    final isFav = await db.isFavorite(widget.word);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    if (widget.isAi) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.toggleFavorite(widget.word);
    await _refreshFavorite();
  }

  /// Plain-text version of the meaning, suitable for clipboard and share.
  /// We preserve <br> line breaks and drop every other tag so the user
  /// never sees `<span class=...>` noise outside the app.
  String _plainMeaning() => plainMeaning(widget.word.meaning);

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final settings = Provider.of<SettingsService>(context);
    final sourceName = widget.isAi
        ? settings.strings.get('ai_source')
        : (widget.word.source?.arabicName ?? 'Unknown Source');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(
          color: widget.isAi
              ? colors.accent.withValues(alpha: 0.35)
              : colors.border,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leading accent rule; brighter for AI rows.
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: widget.isAi
                    ? colors.accent
                    : colors.accent.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTokens.radius16),
                  bottomLeft: Radius.circular(AppTokens.radius16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(colors, settings, sourceName),
                    const SizedBox(height: 10),
                    _buildMeanings(colors),
                    if (widget.word.rootWord != null ||
                        widget.word.examples != null) ...[
                      const SizedBox(height: 12),
                      Divider(color: colors.border, height: 1),
                      const SizedBox(height: 10),
                    ],
                    if (widget.word.rootWord != null)
                      _buildRootRow(colors),
                    if (widget.word.examples != null) _buildExamples(colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppColors colors,
    SettingsService settings,
    String sourceName,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SourceChip(
          label: sourceName,
          icon: widget.isAi ? Icons.auto_awesome : Icons.menu_book_rounded,
          isAi: widget.isAi,
          colors: colors,
        ),
        Row(
          children: [
            if (!widget.isAi)
              _ActionIcon(
                icon: _isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border_rounded,
                color: _isFavorite ? colors.accent : colors.textMuted,
                onTap: _toggleFavorite,
              ),
            if (!widget.isAi)
              _ActionIcon(
                icon: Icons.bookmark_add_outlined,
                color: colors.textMuted,
                onTap: () => _showAddToCollectionSheet(context, colors),
              ),
            _ActionIcon(
              icon: Icons.copy_rounded,
              color: colors.textMuted,
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text: '${widget.word.word}\n\n${_plainMeaning()}',
                  ),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(settings.strings.get('copied')),
                    backgroundColor: colors.accent,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            _ActionIcon(
              icon: Icons.ios_share_rounded,
              color: colors.textMuted,
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: '${widget.word.word}\n\n${_plainMeaning()}\n\n— Kamoos',
                    subject: widget.word.word,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeanings(AppColors colors) {
    final meanings = <Widget>[];

    if (widget.word.meaningEn != null && widget.word.meaningEn!.isNotEmpty) {
      meanings.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.word.meaningEn!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: colors.text,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      );
    }

    if (widget.word.meaningUr != null && widget.word.meaningUr!.isNotEmpty) {
      if (meanings.isNotEmpty) meanings.add(const SizedBox(height: 10));
      meanings.add(
        Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              widget.word.meaningUr!,
              style: TextStyle(
                fontSize: 18,
                height: 1.7,
                color: colors.text,
                fontFamily: 'Jameel Noori Nastaleeq',
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      );
    }

    if (meanings.isNotEmpty) meanings.add(const SizedBox(height: 10));
    meanings.add(
      Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: double.infinity,
          child: Text(
            _plainMeaning(),
            style: AppTheme.arabicTextStyle(
              context,
              fontSize: 17,
              color: widget.isAi ? colors.textSecondary : colors.text,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: meanings,
    );
  }

  Widget _buildRootRow(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            'Root: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          Text(
            widget.word.rootWord!,
            style: AppTheme.arabicTextStyle(
              context,
              fontSize: 14,
              color: colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamples(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Examples',
          style: TextStyle(
            fontSize: 13,
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

class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isAi;
  final AppColors colors;
  const _SourceChip({
    required this.label,
    required this.icon,
    required this.isAi,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAi
            ? colors.accent.withValues(alpha: 0.1)
            : colors.bgSecondary,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isAi ? colors.accent : colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAi ? colors.accent : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 18, color: color),
      ),
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
    final settings = Provider.of<SettingsService>(context, listen: false);
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
                settings.strings.get('add_to_collection'),
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
                      settings.strings.get('no_collections_found'),
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
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${settings.strings.get('added_to_collection')} ${c['name']}',
                          ),
                          backgroundColor: colors.accent,
                        ),
                      );
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

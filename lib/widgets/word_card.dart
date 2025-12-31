import 'package:flutter/material.dart';
import '../models/word.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;

  const WordCard({super.key, required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _formatMeaningPreview(word.meaning);

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
      margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
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
    final withBreaks = meaning.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    final withoutTags = withBreaks.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final normalizedLines = withoutTags
        .split('\n')
        .map((line) {
          return line.replaceAll(RegExp(r'\s+'), ' ').trim();
        })
        .where((line) => line.isNotEmpty)
        .join('\n');
    if (normalizedLines.isEmpty) {
      return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return normalizedLines;
  }
}

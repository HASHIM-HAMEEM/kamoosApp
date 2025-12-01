import 'package:flutter/material.dart';
import '../../models/word.dart';
import '../theme/tokens.dart';
import '../theme/app_theme.dart';

class EntryCard extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;

  const EntryCard({super.key, required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final preview = _formatMeaningPreview(word.meaning);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppTokens.animDurationFast,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Word Title
                  Hero(
                    tag: 'word_${word.word}',
                    child: Text(
                      word.word,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.arabicTextStyle(
                        context,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Source Chip (Minimal)
                  if (word.source != null)
                    Text(
                      word.source!.arabicName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // Meaning Preview
              Text(
                preview,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.arabicTextStyle(
                  context,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMeaningPreview(String meaning) {
    // Remove HTML-like tags if any, take first line or first 100 chars
    final clean = meaning.replaceAll(RegExp(r'<[^>]*>'), '');
    final lines = clean.split('\n');
    if (lines.isNotEmpty) {
      return lines.first.trim();
    }
    return clean.trim();
  }
}

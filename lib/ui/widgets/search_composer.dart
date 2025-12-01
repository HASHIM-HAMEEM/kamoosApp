import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class SearchComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTap;
  final String hintText;
  final bool isFilterActive;

  const SearchComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilterTap,
    this.hintText = 'Message...',
    this.isFilterActive = false,
  });

  @override
  State<SearchComposer> createState() => _SearchComposerState();
}

class _SearchComposerState extends State<SearchComposer> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      // Rebuild when focus changes
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: AppTokens.animDurationFast,
      curve: AppTokens.animCurve,
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
          width: 1.0,
        ),
        boxShadow: const [], // Flat design
      ),
      child: Row(
        children: [
          // Filter Button (Leading)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4.0),
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                onPressed: widget.onFilterTap,
                icon: Icon(
                  widget.isFilterActive
                      ? Icons.filter_list_alt
                      : Icons.menu_book,
                  color: widget.isFilterActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                  size: 20,
                ),
                tooltip: 'Select Dictionary',
                splashRadius: 20,
              ),
            ),
          ),

          // Text Input
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintTextDirection: TextDirection.rtl,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 14.0,
                ),
                fillColor: Colors.transparent,
              ),
              cursorColor: theme.colorScheme.primary,
            ),
          ),

          // Send/Search Icon (Trailing)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4.0),
            child: AnimatedOpacity(
              opacity: widget.controller.text.isNotEmpty ? 1.0 : 0.5,
              duration: AppTokens.animDurationFast,
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: widget.controller.text.isNotEmpty
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: widget.controller.text.isNotEmpty
                      ? () => widget.onSubmitted(widget.controller.text)
                      : null,
                  icon: Icon(
                    Icons.arrow_upward, // ChatGPT style send arrow
                    color: widget.controller.text.isNotEmpty
                        ? Colors.white
                        : theme.colorScheme.secondary,
                    size: 18,
                  ),
                  splashRadius: 20,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

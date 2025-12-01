import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class Sidebar extends StatelessWidget {
  final VoidCallback? onNewChat;
  final VoidCallback? onSettings;
  final Function(String)? onHistoryItemTap;

  const Sidebar({
    super.key,
    this.onNewChat,
    this.onSettings,
    this.onHistoryItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppTokens.darkText : AppTokens.lightText;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // New Chat Button
            Padding(
              padding: const EdgeInsets.all(AppTokens.spacing12),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  onNewChat?.call();
                },
                borderRadius: BorderRadius.circular(AppTokens.radius8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spacing12,
                    vertical: AppTokens.spacing12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor, width: 1),
                    borderRadius: BorderRadius.circular(AppTokens.radius8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: textColor, size: 18),
                      const SizedBox(width: AppTokens.spacing12),
                      Text(
                        'بحث جديد', // New Search/Chat
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // History List (Placeholder)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spacing12,
                ),
                children: [
                  _buildHistorySection(context, 'اليوم', [
                    'معنى كلمة سلام',
                    'ترجمة book',
                  ]),
                  const SizedBox(height: AppTokens.spacing16),
                  _buildHistorySection(context, 'الأمس', [
                    'شرح الآية 5',
                    'مرادفات جميل',
                  ]),
                ],
              ),
            ),

            // User/Settings (Bottom)
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                onSettings?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(
    BuildContext context,
    String title,
    List<String> items,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spacing12,
            vertical: AppTokens.spacing8,
          ),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
        ...items.map(
          (item) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spacing12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            leading: const Icon(Icons.chat_bubble_outline, size: 16),
            title: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            onTap: () {
              Navigator.pop(context);
              onHistoryItemTap?.call(item);
            },
          ),
        ),
      ],
    );
  }
}

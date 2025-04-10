import 'package:flutter/material.dart';

/// A header widget for sections in the app
class SectionHeader extends StatelessWidget {
  /// The title of the section
  final String title;

  /// Optional action text (e.g., "View All")
  final String? actionText;

  /// Function to call when the action is tapped
  final VoidCallback? onActionTap;

  /// Optional icon to display before the title
  final IconData? icon;

  /// Whether to show the "View All" action
  final bool showViewAll;

  /// Constructor
  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.icon,
    this.showViewAll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          if (actionText != null && showViewAll)
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

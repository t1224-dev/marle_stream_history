import 'package:flutter/material.dart';

/// Placeholder screen for sections that are not yet implemented
class PlaceholderScreen extends StatelessWidget {
  /// The title of the screen
  final String title;

  /// The icon to display
  final IconData icon;

  /// Background color of the placeholder
  final Color? color;

  /// Constructor
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: color?.withAlpha(
          26,
        ), // Changed from withOpacity(0.1) using null-aware operator
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              '$title 画面',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '開発中です',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

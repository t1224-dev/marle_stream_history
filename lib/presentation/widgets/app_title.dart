import 'package:flutter/material.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';

/// App title widget that can be used across screens
class AppTitle extends StatelessWidget {
  /// Constructor
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: 'マール', style: TextStyle(color: AppTheme.primaryColor)),
          TextSpan(text: 'の', style: TextStyle(color: Colors.grey)),
          TextSpan(
            text: '軌跡',
            style: TextStyle(color: AppTheme.secondaryColor),
          ),
        ],
      ),
    );
  }
}

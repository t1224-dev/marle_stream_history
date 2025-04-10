import 'package:flutter/material.dart';

/// A custom navigation bar for the app
class AppNavigationBar extends StatelessWidget {
  /// The current selected index
  final int currentIndex;

  /// Function to call when a tab is tapped
  final Function(int) onTap;

  /// Constructor
  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'ホーム',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'カレンダー',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: '検索',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border_outlined),
          selectedIcon: Icon(Icons.favorite),
          label: 'お気に入り',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '設定',
        ),
      ],
    );
  }
}

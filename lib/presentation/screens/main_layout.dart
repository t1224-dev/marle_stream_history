import 'package:flutter/material.dart';
import 'package:marle_stream_history/presentation/screens/loading/initial_loading_screen.dart';
import 'package:marle_stream_history/presentation/screens/home/home_screen.dart';
import 'package:marle_stream_history/presentation/screens/calendar/calendar_screen.dart';
import 'package:marle_stream_history/presentation/screens/search/search_screen.dart';
import 'package:marle_stream_history/presentation/screens/favorites/favorites_screen.dart';
import 'package:marle_stream_history/presentation/screens/settings/settings_screen.dart';
import 'package:marle_stream_history/presentation/widgets/app_navigation_bar.dart';
import 'package:marle_stream_history/presentation/widgets/app_title.dart';

/// Main layout that manages navigation between screens
class MainLayout extends StatelessWidget {
  final Future<void> initializationFuture;

  /// Constructor
  const MainLayout({super.key, required this.initializationFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _MainContent();
        }
        return InitialLoadingScreen(
          initializationFuture: Future.value(),
          loadingText: 'アプリを起動中...',
        );
      },
    );
  }
}

class _MainContent extends StatefulWidget {
  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  int _selectedIndex = 0;

  // The screens to display based on the selected index
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarScreen(),
    const SearchScreen(),
    FavoritesScreen(key: FavoritesScreen.favoritesKey),
    const SettingsScreen(), // 設定画面を表示するように変更
  ];

  void _onNavigationTap(int index) {
    // 前のインデックスがお気に入りでなく、新しいインデックスがお気に入りの場合、再読み込み
    if (index == 3 && _selectedIndex != 3) {
      // お気に入り画面が表示されたら再読み込み
      // FavoritesScreenの静的メソッドを使用
      FavoritesScreen.reloadFavorites();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppTitle(),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}

/// Placeholder screen for not yet implemented screens
class PlaceholderScreen extends StatelessWidget {
  /// Title of the placeholder screen
  final String title;

  /// Icon to display
  final IconData icon;

  /// Color for the icon
  final Color color;

  /// Constructor
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('準備中です...', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

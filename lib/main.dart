import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marle_stream_history/data/services/database_service.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/presentation/screens/main_layout.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';
import 'package:marle_stream_history/presentation/themes/theme_provider.dart';
import 'package:marle_stream_history/domain/services/settings_service.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初期化処理
  final initializationFuture = _initializeApp();

  runApp(MyApp(initializationFuture: initializationFuture));
}

Future<void> _initializeApp() async {
  try {
    debugPrint('Initializing database...');
    final db = DatabaseService.instance;

    // データベース接続を確立
    await db.database;
    debugPrint('Database connection established');

    // データベースにデータがあるか確認
    final hasData = await db.hasData();
    debugPrint('Database has data: $hasData');

    if (!hasData) {
      debugPrint('Loading initial videos...');
      // 初回起動時はJSONからデータを読み込んでデータベースに保存
      try {
        final videos = await DataLoaderService.loadVideos();
        debugPrint('Loaded ${videos.length} videos from JSON');

        // データベースをクリアしてから保存
        await db.clearDatabase();
        debugPrint('Database cleared');

        await db.insertVideos(videos);
        debugPrint('Successfully inserted ${videos.length} videos to database');
      } catch (e) {
        debugPrint('Error loading initial videos: $e');
        // データベース保存に失敗してもアプリは起動する
      }
    }

    debugPrint('Initialization completed');
  } catch (e) {
    debugPrint('Initialization error: $e');
    // 初期化エラーが発生してもアプリは起動する
  }
}

/// Root widget of the application
class MyApp extends StatelessWidget {
  final Future<void> initializationFuture;

  /// Constructor
  const MyApp({super.key, required this.initializationFuture});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Register all providers here
        ChangeNotifierProvider(create: (_) => SettingsService()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteService()..init()),
      ],
      child: Consumer2<ThemeProvider, SettingsService>(
        builder: (context, themeProvider, settingsService, _) {
          // Initialize theme based on settings
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            themeProvider.setThemeMode(settingsService.themeMode);
          });
          
          return MaterialApp(
            title: 'マールの軌跡',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: ThemeMode.light,
            home: MainLayout(initializationFuture: initializationFuture),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

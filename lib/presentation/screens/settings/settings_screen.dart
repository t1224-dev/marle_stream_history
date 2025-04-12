import 'package:flutter/material.dart';
import 'package:marle_stream_history/domain/services/cache_service.dart';
import 'package:marle_stream_history/domain/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:marle_stream_history/data/services/database_service.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings screen for the application
class SettingsScreen extends StatefulWidget {
  /// Constructor
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showArchiveSection = false;
  String _cacheSize = '計算中...';
  bool _isClearingCache = false;
  bool _isResettingDatabase = false;
  final _cacheService = CacheService(); // 直接インスタンス化
  final _databaseService = DatabaseService.instance; // データベースサービス

  @override
  void initState() {
    super.initState();

    // Check if archive mode is already enabled
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    _showArchiveSection = settingsService.enableArchiveUrls;
    
    // Get cache size
    _updateCacheSize();
  }
  
  /// Update the cache size display
  Future<void> _updateCacheSize() async {
    final size = await _cacheService.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheSize = _cacheService.formatCacheSize(size);
      });
    }
  }
  
  /// Clear the application cache
  Future<void> _clearCache() async {
    setState(() {
      _isClearingCache = true;
    });
    
    final success = await _cacheService.clearCache();
    
    if (mounted) {
      setState(() {
        _isClearingCache = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'キャッシュをクリアしました' : 'キャッシュのクリアに失敗しました',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Update the cache size display
      _updateCacheSize();
    }
  }

  /// Reset database and reload from JSON
  Future<void> _resetDatabase() async {
    // 確認ダイアログの表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データベースをリセット'),
        content: const Text(
          'ローカルデータベースの内容がすべて削除され、初期データから再構築されます。\n'
          'お気に入り設定などのユーザーデータも失われますがよろしいですか？'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセット'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isResettingDatabase = true;
    });

    try {
      // お気に入りデータをクリア (mountedチェックを追加)
      if (mounted) {
        final favoriteService = Provider.of<FavoriteService>(
          context,
          listen: false,
        );
        await favoriteService.clearFavorites();
      } else {
        // mounted でない場合は処理を中断
        return;
      }

      // データベースをクリア
      await _databaseService.clearDatabase();
      
      // JSONからデータを再読み込み
      DataLoaderService.clearCache(); // キャッシュをクリア
      final videos = await DataLoaderService.loadVideos();
      
      // 完了メッセージの表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データベースをリセットしました（${videos.length}件のデータを読み込み）'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('データベースのリセットに失敗しました: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingDatabase = false;
        });
      }
    }
  }

  /// Handle tap on version number
  void _handleVersionTap() {
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    final activated = settingsService.handleVersionTap();

    if (activated) {
      setState(() {
        _showArchiveSection = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アーカイブモードが有効になりました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// メール送信機能
  Future<void> _launchEmail() async {
    const email = 'develop.t1224@gmail.com'; // 指定されたメールアドレス
    const subject = 'マールの軌跡に関するお問い合わせ・ご要望'; // メールタイトル
    const body = '以下の内容でお問い合わせいたします。\n\n'
        '【ご利用の端末機種】：\n'
        '【OSバージョン】：\n'
        '【アプリのバージョン】：\n\n'
        '【お問い合わせ・ご要望内容】：\n（できるだけ詳しくご記入ください）\n';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールアプリを開けませんでした'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: Consumer<SettingsService>(
        builder: (context, settingsService, _) {
          return ListView(
            children: [
              // Storage and Cache
              _buildSectionHeader('ストレージとキャッシュ'),
              // データベースリセット機能
              ListTile(
                title: const Text('データベースをリセット'),
                subtitle: const Text('ローカルデータベースを初期化し、JSONファイルから再読み込み'),
                leading: _isResettingDatabase 
                  ? const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                onTap: _isResettingDatabase ? null : _resetDatabase,
              ),
              // キャッシュクリア機能
              ListTile(
                title: const Text('キャッシュをクリア'),
                subtitle: Text('一時ファイルを削除（現在のサイズ: $_cacheSize）'),
                leading: _isClearingCache 
                  ? const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services),
                onTap: _isClearingCache ? null : _clearCache,
              ),
              const Divider(),

              // App information
              _buildSectionHeader('アプリ情報'),
              // バージョン表示 - タイル全体をタップ可能に
              InkWell(
                onTap: _handleVersionTap,
                child: ListTile(
                  title: const Text('バージョン'),
                  subtitle: const Text('1.0.1'),
                  leading: const Icon(Icons.info_outline),
                ),
              ),
              
              ListTile(
                title: const Text('開発者'),
                subtitle: const Text('kurage'),
                leading: const Icon(Icons.code),
              ),

              // お問い合わせ・要望
              ListTile(
                title: const Text('お問い合わせ・要望'),
                subtitle: const Text('メールでご連絡ください'),
                leading: const Icon(Icons.email),
                onTap: _launchEmail,
              ),

              // Hidden archive section
              if (_showArchiveSection) ...[
                const Divider(),
                _buildSectionHeader('アーカイブ設定 (開発者向け)'),
                SwitchListTile(
                  title: const Text('アーカイブURLを表示'),
                  subtitle: const Text('動画詳細画面にアーカイブURLへのアクセスを表示'),
                  value: settingsService.enableArchiveUrls,
                  onChanged: (_) => settingsService.toggleArchiveUrls(),
                  secondary: const Icon(Icons.archive),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '注意: この機能は開発者向けの機能です。一般ユーザーは使用しないでください。',
                    style: TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              
              // About the app
              const Divider(),
              _buildSectionHeader('このアプリについて'),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'このアプリは引退したVtuber「マール・アストレア」の活動の軌跡を記録するために作成された非公式のファンアプリです。\n\n'
                  '全ての著作権はマール・アストレアさんに帰属します。',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              
              // For padding at the bottom
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  /// Build a section header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

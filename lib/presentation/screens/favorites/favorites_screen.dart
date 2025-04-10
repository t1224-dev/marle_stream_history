import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';
import 'package:marle_stream_history/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:marle_stream_history/presentation/widgets/section_header.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';

/// Screen displaying the user's favorite videos
class FavoritesScreen extends StatefulWidget {
  /// Constructor
  const FavoritesScreen({super.key});

  /// お気に入り画面のインスタンスを保持するためのキー
  static final GlobalKey<FavoritesScreenState> favoritesKey =
      GlobalKey<FavoritesScreenState>();

  /// お気に入りを再読み込みするための静的メソッド
  static void reloadFavorites() {
    favoritesKey.currentState?._loadFavorites();
  }

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

/// お気に入り画面の状態を管理するクラス
class FavoritesScreenState extends State<FavoritesScreen> {
  List<YoutubeVideo> _favoriteVideos = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  final Set<String> _selectedVideoIds = {};

  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 初回のみロードする
    if (_isFirstLoad) {
      _loadFavorites();
      _isFirstLoad = false;
    }
  }

  Future<void> _loadFavorites() async {
    // 非同期処理の前にFavoriteServiceを取得
    final favoriteService = Provider.of<FavoriteService>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all videos from DataLoaderService
      final allVideos = await DataLoaderService.loadVideos();

      // 全ての動画のお気に入り状態を更新
      final updatedVideos = favoriteService.updateVideosWithFavoriteStatus(
        allVideos,
      );

      // Filter videos that are in favorites
      _favoriteVideos =
          updatedVideos.where((video) => video.isFavorite).toList();

      // Sort by most recently added to favorites
      _favoriteVideos.sort((a, b) {
        final aFavorite = favoriteService.getFavorite(a.videoId);
        final bFavorite = favoriteService.getFavorite(b.videoId);

        // どちらもnullの場合は順序を変えない
        if (aFavorite == null && bFavorite == null) {
          return 0;
        }

        // aがnullの場合はbを優先
        if (aFavorite == null) {
          return 1;
        }

        // bがnullの場合はaを優先
        if (bFavorite == null) {
          return -1;
        }

        // 両方存在する場合は追加日時で比較（新しいものが先）
        return bFavorite.addedAt.compareTo(aFavorite.addedAt);
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 編集モードの切り替え
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedVideoIds.clear();
    });
  }

  /// 動画の選択状態を切り替え
  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        _selectedVideoIds.add(videoId);
      }
    });
  }

  /// 選択した動画をお気に入りから削除
  Future<void> _removeSelectedVideos() async {
    if (_selectedVideoIds.isEmpty) return;

    final favoriteService = Provider.of<FavoriteService>(
      context,
      listen: false,
    );

    // 選択された各動画をお気に入りから削除
    for (final videoId in _selectedVideoIds) {
      await favoriteService.removeFavorite(videoId);
    }

    // mountedチェックを追加
    if (mounted) {
      // 選択をクリアして編集モードを終了
      setState(() {
        _selectedVideoIds.clear();
        _isEditMode = false;
      });

      // お気に入りリストを再読み込み
      await _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the favorites service
    return Consumer<FavoriteService>(
      builder: (context, favoriteService, child) {
        return RefreshIndicator(
          onRefresh: _loadFavorites,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SectionHeader(
                          title: 'お気に入り',
                          icon: Icons.favorite,
                          showViewAll: false,
                        ),
                      ),
                      if (_favoriteVideos.isNotEmpty)
                        Row(
                          children: [
                            if (_isEditMode && _selectedVideoIds.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '選択した項目を削除',
                                onPressed: _removeSelectedVideos,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            IconButton(
                              icon: Icon(
                                _isEditMode ? Icons.close : Icons.edit,
                              ),
                              tooltip: _isEditMode ? '編集モードを終了' : '編集モード',
                              onPressed: _toggleEditMode,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_favoriteVideos.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'お気に入りの動画がありません',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '動画詳細画面のハートアイコンをタップして\nお気に入りに追加できます',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final video = _favoriteVideos[index];
                      return Stack(
                        children: [
                          VideoCard(
                            video: video,
                            onTap:
                                _isEditMode
                                    ? () => _toggleVideoSelection(video.videoId)
                                    : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => VideoDetailScreen(
                                                video: video,
                                              ),
                                        ),
                                      ).then((_) => _loadFavorites());
                                    },
                          ),
                          if (_isEditMode)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      _selectedVideoIds.contains(video.videoId)
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Colors.grey.withAlpha(179),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    _selectedVideoIds.contains(video.videoId)
                                        ? Icons.check
                                        : Icons.circle_outlined,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }, childCount: _favoriteVideos.length),
                  ),
                ),
              // Add some padding at the bottom
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

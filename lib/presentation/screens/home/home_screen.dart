import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/widgets/featured_video_card.dart';
import 'package:marle_stream_history/presentation/widgets/horizontal_video_list.dart';
import 'package:marle_stream_history/presentation/widgets/profile_header.dart';
import 'package:marle_stream_history/presentation/widgets/section_header.dart';
import 'package:marle_stream_history/presentation/widgets/category_scroller.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';
import 'package:marle_stream_history/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:marle_stream_history/presentation/screens/search/search_screen.dart';
import 'package:shimmer/shimmer.dart';

/// Home screen of the application
class HomeScreen extends StatefulWidget {
  /// Constructor
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCategory;
  bool _showGrid = false;
  bool _isLoading = false;
  late SharedPreferences _prefs;

  // データの読み込み状態を追跡するためのFuture
  Future<List<YoutubeVideo>> _recentVideosFuture = Future.value([]);
  Future<List<YoutubeVideo>> _featuredVideosFuture = Future.value([]);
  Future<List<String>> _allTagsFuture = Future.value([]);
  // すべてのタグをキャッシュするリスト
  List<String> _allTags = [];

  // ページング用の変数
  int _currentPage = 0;
  List<YoutubeVideo> _loadedVideos = [];
  bool _hasMoreVideos = true;

  @override
  void initState() {
    super.initState();
    // 永続化データの読み込みと初期化
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _prefs = prefs;
        _selectedCategory = _prefs.getString('selectedCategory');
      });
    });
    _loadData();
  }

  // データの読み込み
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _recentVideosFuture = _getRecentVideos();
      _featuredVideosFuture = _getFeaturedVideos();
      
      // タグをロードしてキャッシュする
      _allTagsFuture = _getAllTags();
      _allTags = await _allTagsFuture; // この行を追加してタグを即時読み込み

      // すべてのデータロードを待機
      await Future.wait([
        _recentVideosFuture,
        _featuredVideosFuture,
      ]);

      // 初期ページのロード
      await _loadNextPage();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading data: $e');
    }
  }

  // 次のページをロード
  Future<void> _loadNextPage() async {
    if (!_hasMoreVideos || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await DataLoaderService.loadVideosWithPagination(
        _currentPage,
      );

      setState(() {
        if (videos.isEmpty) {
          _hasMoreVideos = false;
        } else {
          _loadedVideos.addAll(videos);
          _currentPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading videos: $e');
    }
  }

  /// ビデオを表示用に取得
  Future<List<YoutubeVideo>> _getRecentVideos() {
    return DataLoaderService.loadVideosWithPagination(0);
  }

  /// 注目のビデオを取得
  Future<List<YoutubeVideo>> _getFeaturedVideos() {
    return DataLoaderService.loadVideos().then((videos) {
      videos.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return videos.take(3).toList();
    });
  }

  /// すべてのタグを取得
  Future<List<String>> _getAllTags() async {
    try {
      final videos = await DataLoaderService.loadVideos();
      final allTags = <String>{};
      for (final video in videos) {
        allTags.addAll(video.tags);
      }
      return ['すべて', ...allTags.toList()..sort()];
    } catch (e) {
      debugPrint('タグ読み込みエラー: $e');
      return ['すべて']; // エラー時は「すべて」タグだけを返す
    }
  }

  /// カテゴリー別のビデオを取得
  Future<List<YoutubeVideo>> _getVideosByCategory() async {
    if (_selectedCategory == null || _selectedCategory == 'すべて') {
      return _loadedVideos;
    }
    final videos = await DataLoaderService.loadVideos();
    return videos
        .where((video) => video.tags.contains(_selectedCategory))
        .toList();
  }

  /// Handle category selection
  void _handleCategorySelected(String category) {
    setState(() {
      if (category == 'すべて') {
        _selectedCategory = null;
        _prefs.remove('selectedCategory');
      } else {
        _selectedCategory = category;
        _prefs.setString('selectedCategory', category);
      }
    });
  }

  /// Toggle between grid and list view
  void _toggleViewMode() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  /// Handle video tap
  void _handleVideoTap(YoutubeVideo video) {
    // 動画詳細画面にナビゲーション
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(video: video)),
    );
  }

  /// Build a grid of videos
  Widget _buildVideoGrid(List<YoutubeVideo> videos) {
    // 表示数を制限して、オーバーフローを防止
    final limitedVideos = videos.length > 6 ? videos.sublist(0, 6) : videos;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: limitedVideos.length,
      itemBuilder: (context, index) {
        return VideoCard(
          video: limitedVideos[index],
          onTap: () => _handleVideoTap(limitedVideos[index]),
        );
      },
    );
  }

  /// Build a list of videos
  Widget _buildVideoList(List<YoutubeVideo> videos) {
    // 表示数を制限して、オーバーフローを防止
    final limitedVideos = videos.length > 4 ? videos.sublist(0, 4) : videos;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: limitedVideos.length,
      itemBuilder: (context, index) {
        return VideoCard(
          video: limitedVideos[index],
          isHorizontal: true,
          onTap: () => _handleVideoTap(limitedVideos[index]),
        );
      },
    );
  }

  /// Build a loading shimmer effect
  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.all(8.0),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false, // ボトムナビゲーションバーのためにfalseに設定
            child: RefreshIndicator(
              onRefresh: () async {
                // データを再読み込み
                DataLoaderService.clearCache();
                setState(() {
                  _currentPage = 0;
                  _loadedVideos = [];
                  _hasMoreVideos = true;
                });
                await _loadData();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent) {
                    _loadNextPage();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    bottom: 20,
                  ), // パディングを120から50に減らす
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // プロフィールヘッダー
                      const ProfileHeader(),

                      // 最近の配信セクション
                      SectionHeader(
                        title: '最近の配信',
                        actionText: '全て見る',
                        onActionTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const SearchScreen(fromViewAll: true),
                            ),
                          );
                        },
                      ),
                      FutureBuilder<List<YoutubeVideo>>(
                        future: _recentVideosFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return SizedBox(
                              height: 250,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text('データの読み込みエラー: ${snapshot.error}'),
                              ),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: Text('データがありません')),
                            );
                          }

                          return HorizontalVideoList(
                            videos: snapshot.data!,
                            onVideoTap: _handleVideoTap,
                          );
                        },
                      ),

                      // 注目の配信セクション
                      SectionHeader(title: '注目の配信'),
                      FutureBuilder<List<YoutubeVideo>>(
                        future: _featuredVideosFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingShimmer();
                          } else if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text('データの読み込みエラー: ${snapshot.error}'),
                              ),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: Text('注目の配信がありません')),
                            );
                          }

                          return Column(
                            children:
                                snapshot.data!
                                    .map(
                                      (video) => FeaturedVideoCard(
                                        video: video,
                                        onTap: () => _handleVideoTap(video),
                                      ),
                                    )
                                    .toList(),
                          );
                        },
                      ),

                      // カテゴリーフィルターセクション
                      const SizedBox(height: 16),
                      SectionHeader(
                        title: 'カテゴリーから探す',
                        actionText: _showGrid ? 'リスト表示' : 'グリッド表示',
                        onActionTap: _toggleViewMode,
                      ),
                      SizedBox(
                        // CategoryScrollerの高さを固定して、読み込み中もレイアウトが変わらないようにする
                        height: 58, // CategoryScrollerの実際の高さに合わせて調整
                        child: _isLoading 
                          ? Container(
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: CategoryScroller(
                                categories: _allTags, // あらかじめロードしたタグを直接渡す
                                selectedCategory: _selectedCategory,
                                onCategorySelected: _handleCategorySelected,
                              ),
                            ),
                      ),

                      // フィルタリングされたビデオのグリッド/リスト
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FutureBuilder<List<YoutubeVideo>>(
                          future: _getVideosByCategory(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _loadedVideos.isEmpty) {
                              return _buildLoadingShimmer();
                            } else if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text('データの読み込みエラー: ${snapshot.error}'),
                                ),
                              );
                            } else if ((!snapshot.hasData ||
                                    snapshot.data!.isEmpty) &&
                                _loadedVideos.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: Text('該当するビデオがありません')),
                              );
                            }

                            final videos = snapshot.data ?? _loadedVideos;
                            return _showGrid
                                ? _buildVideoGrid(videos)
                                : _buildVideoList(videos);
                          },
                        ),
                      ),

                      // 追加のローディングインジケータ（ページング用）
                      if (_hasMoreVideos)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      // 下部にスペースを追加（必要最小限に調整）
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // フルスクリーンローディングオーバーレイ（初回データロード時）
          if (_isLoading && _loadedVideos.isEmpty)
            Container(
              color: Colors.white.withAlpha(229),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/icon/Marle_icon.jpg',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'マールの配信データを準備中...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '初回起動時はデータの展開に時間がかかります\n少々お待ちください',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '配信データを楽しみにお待ちください！',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

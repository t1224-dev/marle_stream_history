import 'package:flutter/material.dart';
import 'package:marle_stream_history/data/video_data_manager.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:marle_stream_history/presentation/widgets/category_scroller.dart';
import 'package:marle_stream_history/presentation/widgets/section_header.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';
import 'package:shimmer/shimmer.dart';

/// 並び替え基準
enum SortCriteria {
  /// 公開日（新しい順）
  dateDesc,

  /// 公開日（古い順）
  dateAsc,

  /// 配信時間（短い順）
  durationAsc,

  /// 配信時間（長い順）
  durationDesc,
}

/// 全ての動画を表示する画面
class AllVideosScreen extends StatefulWidget {
  /// Constructor
  const AllVideosScreen({super.key});

  @override
  State<AllVideosScreen> createState() => _AllVideosScreenState();
}

class _AllVideosScreenState extends State<AllVideosScreen> {
  String? _selectedCategory;
  bool _showGrid = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  SortCriteria _sortCriteria = SortCriteria.dateDesc;

  // データの読み込み状態を追跡するためのFuture
  late Future<List<YoutubeVideo>> _videosFuture;
  late Future<List<String>> _allTagsFuture;

  @override
  void initState() {
    super.initState();
    // 初期データの読み込み
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // データの読み込み
  void _loadData() {
    _videosFuture = _getVideos();
    _allTagsFuture = VideoDataManager.getAllTags();
  }

  /// ビデオを取得
  Future<List<YoutubeVideo>> _getVideos() async {
    List<YoutubeVideo> videos;

    if (_selectedCategory == null || _selectedCategory == 'すべて') {
      videos = await VideoDataManager.getRecentVideos();
    } else {
      videos = await VideoDataManager.getVideosByTag(_selectedCategory!);
    }

    // 検索クエリがあればフィルタリング
    if (_searchQuery.isNotEmpty) {
      videos =
          videos.where((video) {
            final title = video.title.toLowerCase();
            final query = _searchQuery.toLowerCase();
            return title.contains(query);
          }).toList();
    }

    // 選択されたソート基準でソート
    switch (_sortCriteria) {
      case SortCriteria.dateDesc:
        videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        break;
      case SortCriteria.dateAsc:
        videos.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
        break;
      case SortCriteria.durationAsc:
        videos.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortCriteria.durationDesc:
        videos.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    return videos;
  }

  /// Handle category selection
  void _handleCategorySelected(String category) {
    setState(() {
      if (category == 'すべて') {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
      // カテゴリが変更されたら再読み込み
      _videosFuture = _getVideos();
    });
  }

  /// Handle search query change
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      // 検索クエリが変更されたら再読み込み
      _videosFuture = _getVideos();
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(video: video)),
    );
  }

  /// Build a grid of videos
  Widget _buildVideoGrid(List<YoutubeVideo> videos) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return VideoCard(
          video: videos[index],
          onTap: () => _handleVideoTap(videos[index]),
        );
      },
    );
  }

  /// Build a list of videos
  Widget _buildVideoList(List<YoutubeVideo> videos) {
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return VideoCard(
          video: videos[index],
          isHorizontal: true,
          onTap: () => _handleVideoTap(videos[index]),
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
          5,
          (index) => Container(
            margin: const EdgeInsets.all(8.0),
            height: 120,
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
      appBar: AppBar(title: const Text('全ての配信')),
      body: Column(
        children: [
          // 検索ボックス
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '動画を検索...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _handleSearch('');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _handleSearch,
            ),
          ),

          // カテゴリーフィルターセクション
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SectionHeader(
              title: 'カテゴリーで絞り込む',
              actionText: _showGrid ? 'リスト表示' : 'グリッド表示',
              onActionTap: _toggleViewMode,
            ),
          ),
          FutureBuilder<List<String>>(
            future: _allTagsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              } else if (snapshot.hasError || !snapshot.hasData) {
                return Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: Text('カテゴリーの読み込みに失敗しました: ${snapshot.error}'),
                );
              }

              return CategoryScroller(
                selectedCategory: _selectedCategory,
                onCategorySelected: _handleCategorySelected,
              );
            },
          ),

          // ソートオプション
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DropdownButtonFormField<SortCriteria>(
              value: _sortCriteria,
              decoration: InputDecoration(
                labelText: '並び替え',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: const [
                DropdownMenuItem(
                  value: SortCriteria.dateDesc,
                  child: Text('公開日（新しい順）'),
                ),
                DropdownMenuItem(
                  value: SortCriteria.dateAsc,
                  child: Text('公開日（古い順）'),
                ),
                DropdownMenuItem(
                  value: SortCriteria.durationAsc,
                  child: Text('配信時間（短い順）'),
                ),
                DropdownMenuItem(
                  value: SortCriteria.durationDesc,
                  child: Text('配信時間（長い順）'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sortCriteria = value;
                    _videosFuture = _getVideos();
                  });
                }
              },
            ),
          ),

          // 動画一覧
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder<List<YoutubeVideo>>(
                future: _videosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingShimmer();
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('データの読み込みエラー: ${snapshot.error}'),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('該当する動画が見つかりませんでした'));
                  }

                  final videos = snapshot.data!;

                  // 結果カウンターの表示
                  if (videos.isEmpty) {
                    return const Center(child: Text('該当する動画が見つかりませんでした'));
                  }

                  return Column(
                    children: [
                      // 結果数の表示
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '${videos.length}件の動画が見つかりました',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // 動画リスト
                      Expanded(
                        child:
                            _showGrid
                                ? _buildVideoGrid(videos)
                                : _buildVideoList(videos),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

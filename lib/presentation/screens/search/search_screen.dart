import 'package:flutter/material.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:marle_stream_history/presentation/widgets/category_scroller.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';

// 修正内容:
// - フィルター適用は「適用する」ボタン押下時のみ
// - 現在選択中のソートボタンも再度押下可能に
// - パフォーマンス改善（動画データキャッシュ）
// - 不要コード削除（未使用アニメーション、メソッドなど）
// - トースト表示時のエラー修正（アクションボタンによるコンテキスト問題を解消）

/// Build a loading shimmer effect
Widget _buildLoadingShimmer() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: ListView.builder(
      // スクロール可能なリストを使用
      itemCount: 5,
      itemBuilder:
          (context, index) => Container(
            margin: const EdgeInsets.all(8.0),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
    ),
  );
}

/// 動画検索画面
class SearchScreen extends StatefulWidget {
  /// Flag indicating if the screen was accessed from 'view all'
  final bool fromViewAll;

  /// Constructor
  const SearchScreen({super.key, this.fromViewAll = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// 並び替え基準
enum SortCriteria {
  /// 公開日（新しい順）
  dateDesc,

  /// 公開日（古い順）
  dateAsc,

  /// 再生数（多い順）
  viewsDesc,

  /// 再生数（少ない順）
  viewsAsc,

  /// 高評価数（多い順）
  likesDesc,

  /// 高評価数（少ない順）
  likesAsc,

  /// 配信時間（短い順）
  durationAsc,

  /// 配信時間（長い順）
  durationDesc,
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCategory;
  bool _showGrid = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  SortCriteria _sortCriteria = SortCriteria.dateDesc;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  // カテゴリスクローラー用のスクロールコントローラー
  final ScrollController _categoryScrollController = ScrollController();

  // 全動画データをキャッシュ
  List<YoutubeVideo>? _allVideosCache;

  // データの読み込み状態を追跡するためのFuture
  late Future<List<YoutubeVideo>> _videosFuture;
  late Future<List<String>> _allTagsFuture;

  // お気に入りサービスのリスナーが追加されたかどうかのフラグ
  bool _favoriteListenerAdded = false;
  // お気に入りサービスを保存するための変数
  FavoriteService? _favoriteService;

  @override
  void initState() {
    super.initState();

    // フォーカスリスナーの設定
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });

    // 初期データの読み込み
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // お気に入りサービスのリスナーを設定（まだ追加されていない場合のみ）
    if (!_favoriteListenerAdded) {
      _favoriteService = Provider.of<FavoriteService>(context, listen: false);
      _favoriteService!.addListener(_handleFavoriteChange);
      _favoriteListenerAdded = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _categoryScrollController.dispose();

    // お気に入りサービスのリスナーを削除
    if (_favoriteListenerAdded && _favoriteService != null) {
      _favoriteService!.removeListener(_handleFavoriteChange);
    }

    super.dispose();
  }

  // データの読み込み
  void _loadData() async {
    // 初回のみ実際にデータを読み込み、以降はキャッシュを使用
    _videosFuture = DataLoaderService.loadVideos().then((videos) {
      _allVideosCache = videos;

      // お気に入り状態を更新
      return _updateVideosWithFavoriteStatus(videos);
    });
    _allTagsFuture = DataLoaderService.extractAllTags();
  }

  // お気に入り状態が変更された時の処理
  void _handleFavoriteChange() {
    if (mounted) {
      setState(() {
        // お気に入り状態が変更されたため、キャッシュされた動画データを更新
        if (_allVideosCache != null) {
          _allVideosCache = _updateVideosWithFavoriteStatus(_allVideosCache!);
        }

        // 動画データを再取得
        _videosFuture = _getVideos();
      });
    }
  }

  // 動画リストにお気に入り状態を適用
  List<YoutubeVideo> _updateVideosWithFavoriteStatus(
    List<YoutubeVideo> videos,
  ) {
    final favoriteService =
        _favoriteService ??
        Provider.of<FavoriteService>(context, listen: false);
    return videos.map((video) {
      // 動画のお気に入り状態を設定
      final isFavorite = favoriteService.isFavorite(video.videoId);
      return video.copyWith(isFavorite: isFavorite);
    }).toList();
  }

  /// ソート基準に応じたラベルを取得
  String get sortCriteriaLabel {
    switch (_sortCriteria) {
      case SortCriteria.dateDesc:
        return '公開日（新しい順）';
      case SortCriteria.dateAsc:
        return '公開日（古い順）';
      case SortCriteria.viewsDesc:
        return '再生数（多い順）';
      case SortCriteria.viewsAsc:
        return '再生数（少ない順）';
      case SortCriteria.likesDesc:
        return '高評価数（多い順）';
      case SortCriteria.likesAsc:
        return '高評価数（少ない順）';
      case SortCriteria.durationDesc:
        return '配信時間（長い順）';
      case SortCriteria.durationAsc:
        return '配信時間（短い順）';
    }
  }

  /// ビデオを取得してソート
  Future<List<YoutubeVideo>> _getVideos() async {
    // デバッグログ追加
    print('_getVideos called, selectedCategory: $_selectedCategory');

    // キャッシュがあれば使用し、なければデータを読み込み
    List<YoutubeVideo> videos;
    if (_allVideosCache != null) {
      print('Using cached videos: ${_allVideosCache!.length}');
      videos = List.from(_allVideosCache!);
    } else {
      print('Loading videos from DataLoaderService');
      videos = await DataLoaderService.loadVideos();
      _allVideosCache = videos;
      print('Loaded ${videos.length} videos from DataLoaderService');
    }

    // お気に入り状態を更新
    videos = _updateVideosWithFavoriteStatus(videos);
    print('After favorite update, videos count: ${videos.length}');

    // 重要な修正: タグによるフィルタリング
    if (_selectedCategory != null && _selectedCategory != 'すべて') {
      print('Filtering by category: $_selectedCategory');
      // タグのリストをログ出力して確認
      print('Sample video tags: ${videos.isNotEmpty ? videos.first.tags : []}');

      // すべてのタグを集めて出力（デバッグ用）
      final allTags = videos.expand((v) => v.tags).toSet().toList();
      print('All available tags (${allTags.length}): $allTags');

      // フィルタリング前後の件数を比較するためにカウント
      int beforeCount = videos.length;

      // 修正: より柔軟なタグマッチングを実装
      videos =
          videos.where((video) {
            // 1. 完全一致を試す
            bool exactMatch = video.tags.any(
              (tag) => tag.trim() == _selectedCategory!.trim(),
            );

            // 2. 完全一致がなければ部分一致を試す
            if (!exactMatch) {
              bool partialMatch = video.tags.any(
                (tag) => tag.trim().toLowerCase().contains(
                  _selectedCategory!.trim().toLowerCase(),
                ),
              );
              return partialMatch;
            }

            return exactMatch;
          }).toList();

      print('Filtered from $beforeCount to ${videos.length} videos');

      // フィルタリング結果が0件の場合は追加診断情報を出力
      if (videos.isEmpty) {
        print('WARNING: フィルタリング結果が0件です。選択カテゴリ: $_selectedCategory');
        print('タグ名に揺れがある可能性があります。');
      }
    }

    // 検索クエリがあればフィルタリング
    if (_searchQuery.isNotEmpty) {
      print('Filtering by search query: $_searchQuery');
      videos =
          videos.where((video) {
            final title = video.title.toLowerCase();
            final description = video.description.toLowerCase();
            final query = _searchQuery.toLowerCase();
            return title.contains(query) || description.contains(query);
          }).toList();
      print('After search filter, videos count: ${videos.length}');
    }

    // 選択されたソート基準でソート
    print('Sorting videos by $_sortCriteria');
    switch (_sortCriteria) {
      case SortCriteria.dateDesc:
        videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        break;
      case SortCriteria.dateAsc:
        videos.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
        break;
      case SortCriteria.viewsDesc:
        videos.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case SortCriteria.viewsAsc:
        videos.sort((a, b) => a.viewCount.compareTo(b.viewCount));
        break;
      case SortCriteria.likesDesc:
        videos.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
      case SortCriteria.likesAsc:
        videos.sort((a, b) => a.likeCount.compareTo(b.likeCount));
        break;
      case SortCriteria.durationAsc:
        videos.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortCriteria.durationDesc:
        videos.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    print('Returning ${videos.length} videos');
    return videos;
  }

  /// Handle category selection
  void _handleCategorySelected(String category) {
    // 詳細なデバッグログを追加
    print(
      '_handleCategorySelected: category=$category, previous=$_selectedCategory',
    );

    setState(() {
      if (category == 'すべて') {
        _selectedCategory = null;
        print('Category set to null (すべて selected)');
      } else {
        _selectedCategory = category;
        print('Category set to: $_selectedCategory');
      }
      // キャッシュをクリアして再読み込み
      _allVideosCache = null;
      print('Cache cleared, reloading videos');
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

  /// フィルターオプションを表示
  void _toggleFilterExpansion() {
    _showFilterOptions();
  }

  /// Handle video tap
  void _handleVideoTap(YoutubeVideo video) {
    // 詳細画面に遷移する前のカテゴリを保存
    final String? previousCategory = _selectedCategory;
    print('Navigating to detail, current category: $_selectedCategory');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(video: video)),
    ).then((_) {
      // 詳細画面から戻ってきた時にデータを再読み込み
      print(
        'Returned from detail screen, preserving category: $previousCategory',
      );

      // VideoDataManager から最新データを取得
      DataLoaderService.clearCache(); // 重要: サービスのキャッシュもクリア

      setState(() {
        // カテゴリを保持（これが重要）
        _selectedCategory = previousCategory;
        print('Category set back to: $_selectedCategory');

        // キャッシュをクリアして再読み込み
        _allVideosCache = null;
        print('Cache cleared after return from detail');
        _videosFuture = _getVideos();
      });
    });
  }

  /// Build a grid of videos
  Widget _buildVideoGrid(List<YoutubeVideo> videos) {
    return GridView.builder(
      // スクロール動作の設定
      physics: const AlwaysScrollableScrollPhysics(),
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
      // スクロール動作の設定
      physics: const AlwaysScrollableScrollPhysics(),
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

  /// フィルターオプションを模パネルとして表示
  Future<void> _showFilterOptions() {
    // 現在の値を一時保存（キャンセル時のために保持）
    SortCriteria tempSortCriteria = _sortCriteria; // 現在のソート基準を一時保存
    bool localShowGrid = _showGrid; // 表示形式の現在の状態を保存

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (BuildContext modalContext) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              // モーダルの中で一時的なソート状態を更新するための関数
              void handleSortChange(SortCriteria? newCriteria) {
                if (newCriteria != null) {
                  setModalState(() {
                    tempSortCriteria = newCriteria;
                  });
                }
              }

              // 表示形式切替用関数
              void handleGridChange(bool isGrid) {
                setModalState(() {
                  localShowGrid = isGrid;
                });
              }

              return SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            'ソート基準',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '現在: $sortCriteriaLabel',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color.fromRGBO(
                                138,
                                208,
                                233,
                                0.7,
                              ), // プライマリカラー#8AD0E9 (70% opacity)
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ソート基準ボタンを2列に設定
                          GridView.count(
                            crossAxisCount: 2,
                            childAspectRatio: 3.5, // アスペクト比を調整
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14, // より広い間隔
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildSortChipInModal(
                                SortCriteria.dateDesc,
                                '日付（降順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.dateAsc,
                                '日付（昇順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.viewsDesc,
                                '再生数（降順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.viewsAsc,
                                '再生数（昇順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.likesDesc,
                                '高評価数（降順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.likesAsc,
                                '高評価数（昇順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.durationDesc,
                                '配信時間（降順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                              _buildSortChipInModal(
                                SortCriteria.durationAsc,
                                '配信時間（昇順）',
                                tempSortCriteria,
                                handleSortChange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                '表示形式',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.grid_view),
                                    label: const Text('グリッド'),
                                    onPressed: () => handleGridChange(true),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          localShowGrid
                                              ? Theme.of(
                                                context,
                                              ).primaryColor.withAlpha(51)
                                              : Colors.white,
                                      foregroundColor:
                                          localShowGrid
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[800],
                                      side: BorderSide(
                                        color:
                                            localShowGrid
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[300]!,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.list),
                                    label: const Text('リスト'),
                                    onPressed: () => handleGridChange(false),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          !localShowGrid
                                              ? Theme.of(
                                                context,
                                              ).primaryColor.withAlpha(51)
                                              : Colors.white,
                                      foregroundColor:
                                          !localShowGrid
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[800],
                                      side: BorderSide(
                                        color:
                                            !localShowGrid
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey[300]!,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 適用ボタン
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // 適用前の現在値を保存
                                final SortCriteria previousSortCriteria =
                                    _sortCriteria;

                                // 変更を適用してモーダルを閉じる
                                setState(() {
                                  // 表示形式の適用
                                  _showGrid = localShowGrid;

                                  // 一時保存していた値を実際に適用する
                                  _sortCriteria = tempSortCriteria;

                                  // データを再取得
                                  _videosFuture = _getVideos();

                                  // ソートが変更されている場合のみトースト表示
                                  if (tempSortCriteria !=
                                      previousSortCriteria) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'ソート基準を$sortCriteriaLabelに変更しました',
                                        ),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor:
                                            Theme.of(context).primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        margin: const EdgeInsets.all(8),
                                        // アクションボタンを使わず自動消失するように修正
                                      ),
                                    );
                                  }
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                '適用する',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32), // ボトムシートの下部に余白を追加
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  /// Build sort option chip for the modal bottom sheet
  Widget _buildSortChipInModal(
    SortCriteria criteria,
    String label,
    SortCriteria currentCriteria,
    Function(SortCriteria?) onChangeCriteria,
  ) {
    final isSelected = currentCriteria == criteria;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChangeCriteria(criteria),
          splashColor: const Color.fromRGBO(
            138,
            208,
            233,
            0.2,
          ), // プライマリカラー#8AD0E9 (20% opacity)
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: const Color.fromRGBO(
                            138,
                            208,
                            233,
                            0.4,
                          ), // プライマリカラー#8AD0E9 (40% opacity)
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                if (isSelected) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a modern search bar
  Widget _buildModernSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(_isSearchFocused ? 0 : 8),
      margin: EdgeInsets.symmetric(
        horizontal: _isSearchFocused ? 0 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color:
            _isSearchFocused
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.white,
        borderRadius: BorderRadius.circular(_isSearchFocused ? 0 : 24),
        boxShadow:
            _isSearchFocused
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withAlpha(26), // 0.1->26
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: '動画を検索...',
          prefixIcon: Icon(
            Icons.search,
            color:
                _isSearchFocused
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
          ),
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
          border:
              _isSearchFocused
                  ? UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                  : InputBorder.none,
          focusedBorder:
              _isSearchFocused
                  ? UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  )
                  : InputBorder.none,
          filled: !_isSearchFocused,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: _handleSearch,
        style: const TextStyle(fontSize: 16),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  /// 検索とフィルタをリセットする
  void _resetSearch() {
    setState(() {
      // 検索クエリをリセット
      _searchQuery = '';
      _searchController.clear();

      // 選択カテゴリをリセット
      _selectedCategory = null;

      // ソート基準をデフォルトに戻す
      _sortCriteria = SortCriteria.dateDesc;

      // キャッシュをクリアして再読み込み
      _allVideosCache = null;
      _videosFuture = _getVideos();

      // カテゴリスクローラーのスクロール位置を初期位置に戻す
      if (_categoryScrollController.hasClients) {
        _categoryScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // リセットしたことをユーザーに通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('検索条件をリセットしました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(8),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Add extra space at the top when coming from 'view all'
            if (widget.fromViewAll) const SizedBox(height: 32),

            // タイトルとフィルターボタン
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    '動画検索',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Spacer(),
                  // リセットボタン（画面幅に応じて適応的に表示）
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // 利用可能な幅を取得
                      final availableWidth =
                          MediaQuery.of(context).size.width -
                          80; // ヘッダーの余白などを考慮
                      final isNarrow = availableWidth < 360; // 狭い画面の判定基準

                      return isNarrow
                          ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _resetSearch,
                            tooltip: 'リセット',
                            color: Theme.of(context).primaryColor,
                          )
                          : OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('リセット'),
                            onPressed: _resetSearch,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).primaryColor,
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          );
                    },
                  ),
                  const SizedBox(width: 8),
                  // フィルターボタン（画面幅に応じて適応的に表示）
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth =
                          MediaQuery.of(context).size.width - 80;
                      final isNarrow = availableWidth < 360;

                      return isNarrow
                          ? IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: _toggleFilterExpansion,
                            tooltip: 'フィルター',
                            color: Theme.of(context).primaryColor,
                          )
                          : OutlinedButton.icon(
                            icon: const Icon(Icons.filter_list),
                            label: const Text('フィルター'),
                            onPressed: _toggleFilterExpansion,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).primaryColor,
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          );
                    },
                  ),
                ],
              ),
            ),

            // 検索ボックス
            _buildModernSearchBar(),

            // カテゴリースクローラー
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: FutureBuilder<List<String>>(
                future: _allTagsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError || !snapshot.hasData) {
                    return Container();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: CategoryScroller(
                      selectedCategory: _selectedCategory,
                      onCategorySelected: _handleCategorySelected,
                      scrollController: _categoryScrollController,
                    ),
                  );
                },
              ),
            ),

            // 検索結果カウンター
            FutureBuilder<List<YoutubeVideo>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.hasError ||
                    snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                final videos = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${videos.length}件の動画',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        sortCriteriaLabel,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // 動画一覧（Expandedで囲んで残りのスペースを埋める）
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

                    if (videos.isEmpty) {
                      return const Center(child: Text('該当する動画が見つかりませんでした'));
                    }

                    return _showGrid
                        ? _buildVideoGrid(videos)
                        : _buildVideoList(videos);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        itemBuilder: (context, index) => Container(
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

  // 全動画データをキャッシュ
  List<YoutubeVideo>? _allVideosCache;
  
  // データの読み込み状態を追跡するためのFuture
  late Future<List<YoutubeVideo>> _videosFuture;
  late Future<List<String>> _allTagsFuture;

  // お気に入りサービスのリスナーが追加されたかどうかのフラグ
  bool _favoriteListenerAdded = false;

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
      final favoriteService = Provider.of<FavoriteService>(context, listen: false);
      favoriteService.addListener(_handleFavoriteChange);
      _favoriteListenerAdded = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    // お気に入りサービスのリスナーを削除
    if (_favoriteListenerAdded) {
      final favoriteService = Provider.of<FavoriteService>(context, listen: false);
      favoriteService.removeListener(_handleFavoriteChange);
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
  List<YoutubeVideo> _updateVideosWithFavoriteStatus(List<YoutubeVideo> videos) {
    final favoriteService = Provider.of<FavoriteService>(context, listen: false);
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
    // キャッシュがあれば使用し、なければデータを読み込み
    List<YoutubeVideo> videos;
    if (_allVideosCache != null) {
      videos = List.from(_allVideosCache!);
    } else {
      videos = await DataLoaderService.loadVideos();
      _allVideosCache = videos;
    }
    
    // お気に入り状態を更新
    videos = _updateVideosWithFavoriteStatus(videos);

    if (_selectedCategory != null && _selectedCategory != 'すべて') {
      videos =
          videos
              .where((video) => video.tags.contains(_selectedCategory))
              .toList();
    }

    // 検索クエリがあればフィルタリング
    if (_searchQuery.isNotEmpty) {
      videos =
          videos.where((video) {
            final title = video.title.toLowerCase();
            final description = video.description.toLowerCase();
            final query = _searchQuery.toLowerCase();
            return title.contains(query) || description.contains(query);
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

  /// フィルターオプションを表示
  void _toggleFilterExpansion() {
    _showFilterOptions();
  }

  /// Handle video tap
  void _handleVideoTap(YoutubeVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(video: video)),
    ).then((_) {
      // 詳細画面から戻ってきた時にデータを再読み込み
      setState(() {
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
      builder: (BuildContext modalContext) => StatefulBuilder(
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
                    color: const Color.fromRGBO(138, 208, 233, 0.7), // プライマリカラー#8AD0E9 (70% opacity)
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
                    _buildSortChipInModal(SortCriteria.dateDesc, '日付（降順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.dateAsc, '日付（昇順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.viewsDesc, '再生数（降順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.viewsAsc, '再生数（昇順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.likesDesc, '高評価数（降順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.likesAsc, '高評価数（昇順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.durationDesc, '配信時間（降順）', tempSortCriteria, handleSortChange),
                    _buildSortChipInModal(SortCriteria.durationAsc, '配信時間（昇順）', tempSortCriteria, handleSortChange),
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
                            backgroundColor: localShowGrid ? Theme.of(context).primaryColor.withAlpha(51) : Colors.white,
                            foregroundColor: localShowGrid ? Theme.of(context).primaryColor : Colors.grey[800],
                            side: BorderSide(
                              color: localShowGrid ? Theme.of(context).primaryColor : Colors.grey[300]!,
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
                            backgroundColor: !localShowGrid ? Theme.of(context).primaryColor.withAlpha(51) : Colors.white,
                            foregroundColor: !localShowGrid ? Theme.of(context).primaryColor : Colors.grey[800],
                            side: BorderSide(
                              color: !localShowGrid ? Theme.of(context).primaryColor : Colors.grey[300]!,
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
                      final SortCriteria previousSortCriteria = _sortCriteria;
                      
                      // 変更を適用してモーダルを閉じる
                      setState(() {
                        // 表示形式の適用
                        _showGrid = localShowGrid;
                        
                        // 一時保存していた値を実際に適用する
                        _sortCriteria = tempSortCriteria;
                        
                        // データを再取得
                        _videosFuture = _getVideos();
                          
                        // ソートが変更されている場合のみトースト表示
                        if (tempSortCriteria != previousSortCriteria) {
                          ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ソート基準を$sortCriteriaLabelに変更しました'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('適用する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  Widget _buildSortChipInModal(SortCriteria criteria, String label, SortCriteria currentCriteria, Function(SortCriteria?) onChangeCriteria) {
    final isSelected = currentCriteria == criteria;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChangeCriteria(criteria),
          splashColor: const Color.fromRGBO(138, 208, 233, 0.2), // プライマリカラー#8AD0E9 (20% opacity)
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color.fromRGBO(138, 208, 233, 0.4), // プライマリカラー#8AD0E9 (40% opacity)
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                if (isSelected) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Add extra space at the top when coming from 'view all'
            if (widget.fromViewAll) 
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              
            // タイトルとフィルターボタン
            SliverToBoxAdapter(
              child: Padding(
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
                    // フィルターボタン
                    OutlinedButton.icon(
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 検索ボックス
            SliverToBoxAdapter(child: _buildModernSearchBar()),

            // フィルターオプションはモーダルで表示するのでここでは何も表示しない

            // カテゴリースクローラー
            SliverToBoxAdapter(
              child: Padding(
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
                      ),
                    );
                  },
                ),
              ),
            ),

            // 検索結果カウンター
            SliverToBoxAdapter(
              child: FutureBuilder<List<YoutubeVideo>>(
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
            ),
            
            // 動画一覧
            SliverPadding(
              padding: const EdgeInsets.all(8.0),
              sliver: SliverFillRemaining(
                hasScrollBody: true,
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

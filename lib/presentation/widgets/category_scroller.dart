import 'package:flutter/material.dart';
import 'package:marle_stream_history/data/video_data_manager.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';

/// A horizontal scrollable list of category tags
class CategoryScroller extends StatefulWidget {
  /// Callback when a category is selected
  final Function(String category)? onCategorySelected;

  /// The currently selected category (if any)
  final String? selectedCategory;

  /// 事前に読み込まれたカテゴリリスト
  final List<String>? categories;
  
  /// スクロールコントローラー
  final ScrollController? scrollController;

  /// Constructor
  const CategoryScroller({
    super.key,
    this.onCategorySelected,
    this.selectedCategory,
    this.categories,
    this.scrollController,
  });

  @override
  State<CategoryScroller> createState() => _CategoryScrollerState();
}

class _CategoryScrollerState extends State<CategoryScroller> {
  /// Loading state
  bool _isLoading = true;

  /// Error state
  String? _error;

  /// Available categories
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    
    // 事前にカテゴリが渡されている場合はそれを使用する
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      setState(() {
        _categories = widget.categories!;
        _isLoading = false;
      });
    } else {
      _loadCategories();
    }
  }

  @override
  void didUpdateWidget(CategoryScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // プロパティが更新された場合にカテゴリを更新
    if (widget.categories != null && 
        widget.categories!.isNotEmpty && 
        oldWidget.categories != widget.categories) {
      setState(() {
        _categories = widget.categories!;
        _isLoading = false;
      });
    }
  }

  /// Load categories asynchronously
  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load videos and extract tags
      final allVideos = await VideoDataManager.getVideos();
      final allTags = _extractAllTags(allVideos);

      // Add "All" as the first option
      const allCategory = 'すべて';
      final categories = [allCategory, ...allTags];

      // Update state
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'カテゴリーの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// Extract all unique tags from videos
  List<String> _extractAllTags(List<YoutubeVideo> videos) {
    final allTags = <String>{};
    debugPrint('Extracting tags from ${videos.length} videos');

    for (final video in videos) {
      debugPrint('Video ${video.id} has tags: ${video.tags}');
      allTags.addAll(video.tags.where((tag) => tag.isNotEmpty));
    }

    debugPrint('Found ${allTags.length} unique tags');
    // Sort tags alphabetically
    return allTags.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator
    if (_isLoading) {
      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Show error
    if (_error != null) {
      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    // Show categories
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected =
              widget.selectedCategory == category ||
              (widget.selectedCategory == null && category == 'すべて');

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => widget.onCategorySelected?.call(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: isSelected ? null : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: AppTheme.primaryColor.withAlpha(
                                77,
                              ), // Changed from withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

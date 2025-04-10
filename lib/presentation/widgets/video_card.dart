import 'package:flutter/material.dart';
import 'package:marle_stream_history/utils/date_formatter.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// A card widget that displays a YouTube video with thumbnail and basic info
class VideoCard extends StatelessWidget {
  /// The video to display
  final YoutubeVideo video;

  /// Function to call when the card is tapped
  final VoidCallback? onTap;

  /// Whether to display the card in a horizontal layout (default: false)
  final bool isHorizontal;

  /// Constructor
  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormatter.formatDate(video.publishedAt);
    final relativeTime = DateFormatter.formatRelativeTime(video.publishedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(4.0), // マージンを小さくしてオーバーフローを防止
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child:
            isHorizontal
                ? _buildHorizontalLayout(context, formattedDate, relativeTime)
                : _buildVerticalLayout(context, formattedDate, relativeTime),
      ),
    );
  }

  /// Build a vertical layout for the card
  Widget _buildVerticalLayout(
    BuildContext context,
    String formattedDate,
    String relativeTime,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _buildThumbnail(),
            // Date overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(
                    179,
                  ), // Changed from withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  relativeTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // お気に入りアイコン
            if (video.isFavorite)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8.0), // パディングを小さくしてオーバーフローを防止
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              // タグ表示の改良とオーバーフロー対策
              if (video.tags.isNotEmpty) ...[
                const SizedBox(height: 4), // 高さを8から4に減らしてオーバーフローを防止
                SizedBox(
                  width: double.infinity,
                  height: 16, // 明示的に高さを設定してオーバーフローを防止
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#${video.tags.first}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (video.tags.length > 1)
                        Text(
                          ' +${video.tags.length - 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withAlpha(
                              179,
                            ), // Changed from withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build a horizontal layout for the card
  Widget _buildHorizontalLayout(
    BuildContext context,
    String formattedDate,
    String relativeTime,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Row内のオーバーフローを防ぐための調整
      children: [
        SizedBox(
          width: 120, // 幅をさらに小さくしてオーバーフローを確実に防止
          height: 67.5, // 16:9のアスペクト比に合わせて高さを調整 (120 * 9/16 = 67.5)
          child: Stack(
            children: [
              _buildThumbnail(),
              // Date overlay
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(
                      179,
                    ), // Changed from withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    relativeTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // 再生アイコンのオーバーレイ
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(
                        128,
                      ), // Changed from withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              // お気に入りアイコン
              if (video.isFavorite)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6.0), // パディングをさらに小さくしてオーバーフローを確実に防止
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 視聴回数と日付を表示（Rowをwrapあるいは複数行に分割して対応）
                    Wrap(
                      spacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _formatViewCount(video.viewCount.toInt()),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // 下部にタグを配置
                if (video.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // タグ表示のオーバーフロー対策
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.start,
                      children:
                          video.tags
                              .take(1) // 表示するタグの数を減らしてオーバーフローを防止
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withAlpha(51), // 0.2 -> 51
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the thumbnail image with loading placeholder
  Widget _buildThumbnail() {
    // thumbnailPathからassets/プレフィックスを削除、値がない場合はデフォルト表示を生成
    String assetPath;

    try {
      if (video.thumbnailPath.isEmpty || video.thumbnailPath.endsWith('/')) {
        // サムネイルパスが空またはスラッシュで終わる場合はデフォルト画像を使用
        return _buildDefaultThumbnail();
      } else {
        assetPath =
            video.thumbnailPath.startsWith('assets/')
                ? video.thumbnailPath
                : 'assets/${video.thumbnailPath}';
      }

      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain, // cover から contain に変更して元の画像のアスペクト比を保持
          errorBuilder: (context, error, stackTrace) {
            debugPrint('サムネイル読み込みエラー: $error');
            return _buildDefaultThumbnail();
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('サムネイル処理エラー: $e');
      return _buildDefaultThumbnail();
    }
  }

  /// デフォルトのサムネイル表示を生成
  Widget _buildDefaultThumbnail() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library, color: Colors.grey[400], size: 32),
              const SizedBox(height: 8),
              Text(
                video.title.isNotEmpty
                    ? video.title.substring(0, math.min(video.title.length, 20))
                    : 'タイトルなし',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 再生回数を適切にフォーマットする
  String _formatViewCount(int count) {
    if (count >= 10000) {
      // 1万以上の場合は「X.X万回視聴」形式で表示
      final valueInTenThousands = count / 10000;
      return '${valueInTenThousands.toStringAsFixed(1)}万回視聴';
    } else {
      // 1万未満の場合は通常のフォーマット
      return '${NumberFormat.decimalPattern().format(count)} 回視聴';
    }
  }
}

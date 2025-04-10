import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling video-related operations
class VideoService {
  /// Launch YouTube to watch the video
  static Future<bool> openYouTube(YoutubeVideo video, {BuildContext? context}) async {
    final Uri url = Uri.parse(video.videoUrl);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
    
    // Handle failure if context is provided
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('YouTubeを開けませんでした'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    return false;
  }
  
  /// Share a video with others
  static void shareVideo(YoutubeVideo video, {required BuildContext context}) {
    // In real app, implement platform-specific sharing logic
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('共有機能は現在開発中です'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Copy text to clipboard
  static Future<void> copyToClipboard(String text, {BuildContext? context}) async {
    await Clipboard.setData(ClipboardData(text: text));
    
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('クリップボードにコピーしました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Toggle favorite status of a video
  static Future<void> toggleFavorite(YoutubeVideo video, {required BuildContext context}) async {
    // Use our FavoriteService to handle favorites
    final favoriteService = Provider.of<FavoriteService>(context, listen: false);
    await favoriteService.toggleFavorite(video);
    
    // Show confirmation - mountedチェックを追加
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(video.isFavorite 
              ? 'お気に入りに追加しました' 
              : 'お気に入りから削除しました'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Get related videos based on tags
  static List<YoutubeVideo> getRelatedVideos(
    YoutubeVideo video,
    List<YoutubeVideo> allVideos, {
    int limit = 5,
    bool enableDebugLogs = false,
  }) {
    // 入力検証: allVideosが空の場合は空リストを返す
    if (allVideos.isEmpty) {
      if (enableDebugLogs) debugPrint('関連動画を取得できません: 全動画リストが空です');
      return [];
    }
    
    // 入力検証: videoにタグがない場合は最新の動画を返す
    if (video.tags.isEmpty) {
      if (enableDebugLogs) debugPrint('動画にタグがないため、最新の動画を関連動画として表示します');
      // 日付でソートして最新のものを返す（現在の動画を除外）
      final recentVideos = List<YoutubeVideo>.from(allVideos)
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt))
        ..removeWhere((v) => v.id == video.id);
      
      return recentVideos.take(limit).toList();
    }
    
    if (enableDebugLogs) debugPrint('関連動画を検索中: ${video.tags.first} タグを持つ動画');
    
    // Get videos with the same primary tag, excluding the current video
    final sameTagVideos = allVideos
        .where((v) => 
            v.id != video.id && 
            v.tags.isNotEmpty && 
            v.tags.contains(video.tags.first))
        .toList();
    
    if (enableDebugLogs) debugPrint('同じタグの動画: ${sameTagVideos.length}件');
    
    // If not enough videos with the same tag, add some recent videos
    if (sameTagVideos.length < limit) {
      if (enableDebugLogs) debugPrint('同じタグの動画が$limit件未満のため、他の動画も追加します');
      
      // 日付でソートして最新のものから追加（現在の動画と既に追加した動画を除外）
      final otherVideos = List<YoutubeVideo>.from(allVideos)
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt))
        ..removeWhere((v) => v.id == video.id || sameTagVideos.contains(v))
        ..take(limit - sameTagVideos.length);
      
      sameTagVideos.addAll(otherVideos);
    }
    
    final resultVideos = sameTagVideos.take(limit).toList();
    if (enableDebugLogs) debugPrint('返す関連動画: ${resultVideos.length}件');
    
    return resultVideos;
  }
}

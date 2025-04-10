import 'package:flutter/foundation.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/domain/models/calendar_event.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/data/services/data_source.dart';
import 'package:marle_stream_history/utils/duration_converter.dart';

/// 動画データ管理クラス
class VideoDataManager {
  /// Configure the data source (JSON or CSV)
  static void configureDataSource(DataSource source) {
    DataLoaderService.dataSource = source;
  }
  
  /// Set the CSV file path
  static void setCsvPath(String path) {
    DataLoaderService.csvPath = path;
  }
  
  // キャッシュしたビデオリスト
  static List<YoutubeVideo>? _cachedVideos;
  
  // キャッシュしたカレンダーイベントリスト
  static Map<DateTime, List<CalendarEvent>>? _cachedEvents;
  
  /// Get a list of videos
  static Future<List<YoutubeVideo>> getVideos() async {
    // キャッシュがあればそれを返す
    if (_cachedVideos != null) {
      return _cachedVideos!;
    }
    
    // 初期データを読み込む
    _cachedVideos = await DataLoaderService.loadVideos();
    return _cachedVideos!;
  }
  
  /// Get a list of videos with pagination
  static Future<List<YoutubeVideo>> getVideosWithPagination(int page) async {
    return DataLoaderService.loadVideosWithPagination(page);
  }

  /// Get a list of featured videos
  static Future<List<YoutubeVideo>> getFeaturedVideos() async {
    final allVideos = await getVideos();
    
    // 注目度を計算 (再生数×0.4 + 高評価数×0.6)
    final videosWithScore = allVideos.map((video) {
      final score = (video.viewCount * 0.4) + (video.likeCount * 0.6);
      return {'video': video, 'score': score};
    }).toList();
    
    // 注目度でソート (null安全に)
    videosWithScore.sort((a, b) {
      final scoreA = a['score'] as double;
      final scoreB = b['score'] as double;
      return scoreB.compareTo(scoreA);
    });
    
    // 上位3件を取得
    return videosWithScore
      .take(3)
      .map((item) => item['video'] as YoutubeVideo)
      .toList();
  }

  /// Get recent videos (sorted by date)
  static Future<List<YoutubeVideo>> getRecentVideos() async {
    // データはすでに日付順にソートされている
    return getVideos();
  }
  
  /// Get recent videos with pagination (sorted by date)
  static Future<List<YoutubeVideo>> getRecentVideosWithPagination(int page) async {
    return getVideosWithPagination(page);
  }

  /// Get favorite videos
  static Future<List<YoutubeVideo>> getFavoriteVideos() async {
    final allVideos = await getVideos();
    return allVideos.where((video) => video.isFavorite).toList();
  }
  
  /// Clear the video cache to force reload
  static void clearCache() {
    _cachedVideos = null;
    _cachedEvents = null;
    DataLoaderService.clearCache();
  }
  
  /// Get videos by category/tag
  static Future<List<YoutubeVideo>> getVideosByTag(String tag) async {
    final allVideos = await getVideos();
    return allVideos.where((video) => video.tags.contains(tag)).toList();
  }
  
  /// Get videos by search term
  static Future<List<YoutubeVideo>> searchVideos(String query) async {
    if (query.isEmpty) return [];
    
    final allVideos = await getVideos();
    final lowercaseQuery = query.toLowerCase();
    
    return allVideos.where((video) => 
      video.title.toLowerCase().contains(lowercaseQuery) ||
      video.description.toLowerCase().contains(lowercaseQuery) ||
      video.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery))
    ).toList();
  }

  /// Get all videos
  static Future<List<YoutubeVideo>> getAllVideos() async {
    return getVideos();
  }

  /// Get all unique tags
  static Future<List<String>> getAllTags() async {
    return DataLoaderService.extractAllTags();
  }
  
  /// Get videos grouped by tag
  static Future<Map<String, List<YoutubeVideo>>> getVideosByTagMap() async {
    final allVideos = await getVideos();
    final Map<String, List<YoutubeVideo>> tagMap = {};
    
    for (final video in allVideos) {
      for (final tag in video.tags) {
        if (!tagMap.containsKey(tag)) {
          tagMap[tag] = [];
        }
        tagMap[tag]!.add(video);
      }
    }
    
    return tagMap;
  }
  
  /// Get videos sorted by duration (ascending or descending)
  static Future<List<YoutubeVideo>> getVideosByDuration({bool ascending = true}) async {
    final allVideos = await getVideos();
    
    // Convert duration strings to seconds and sort
    allVideos.sort((a, b) {
      final secondsA = DurationConverter.durationToSeconds(a.duration);
      final secondsB = DurationConverter.durationToSeconds(b.duration);
      return ascending 
          ? secondsA.compareTo(secondsB) 
          : secondsB.compareTo(secondsA);
    });
    
    return allVideos;
  }

  /// Get total view count from all videos
  static Future<double> getTotalViewCount() async {
    final allVideos = await getVideos();
    return allVideos.fold<double>(0, (total, video) => total + video.viewCount);
  }
  
  /// Get the earliest video date
  static Future<DateTime> getEarliestVideoDate() async {
    final allVideos = await getVideos();
    if (allVideos.isEmpty) {
      return DateTime(2020, 1, 1); // デフォルトの開始日
    }
    
    // 最も古い動画の日付を検索
    return allVideos.map((video) => video.publishedAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  }
  
  /// Get the latest video date
  static Future<DateTime> getLatestVideoDate() async {
    final allVideos = await getVideos();
    if (allVideos.isEmpty) {
      return DateTime.now(); // 現在日に設定
    }
    
    // 最も新しい動画の日付を検索
    return allVideos.map((video) => video.publishedAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  }
  
  /// Get events for a specific date
  static Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    // キャッシュ型イベントが存在する場合はキャッシュから返す
    if (_cachedEvents != null) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      return _cachedEvents![normalizedDay] ?? [];
    }
    
    final allVideos = await getVideos();
    final dayStart = DateTime(day.year, day.month, day.day);
    
    // 指定日に公開された動画を抽出
    final videosOnDay = allVideos.where((video) {
      final videoDate = video.publishedAt;
      return videoDate.year == day.year &&
             videoDate.month == day.month &&
             videoDate.day == day.day;
    }).toList();
    
    if (videosOnDay.isEmpty) {
      debugPrint('${day.year}年${day.month}月${day.day}日の動画がありません');
      return [];
    }
    
    // 動画がある場合はイベントを作成
    debugPrint('${day.year}年${day.month}月${day.day}日の動画数: ${videosOnDay.length}');
    return [
      CalendarEvent(
        id: 'event-${dayStart.toIso8601String()}',
        date: dayStart,
        videos: videosOnDay,
      )
    ];
  }
  
  /// Get events for the entire month
  static Future<Map<DateTime, List<CalendarEvent>>> getEventsForMonth(DateTime month) async {
    // キャッシュについては新たにイベントを构築してデータの整合性を確保
    if (_cachedEvents != null) {
      final Map<DateTime, List<CalendarEvent>> monthEvents = {};
      
      // 指定された月のイベントをキャッシュから抽出
      _cachedEvents!.forEach((day, events) {
        if (day.year == month.year && day.month == month.month) {
          monthEvents[day] = events;
        }
      });
      
      return monthEvents;
    }
    
    final allVideos = await getVideos();
    final Map<DateTime, List<CalendarEvent>> eventMap = {};
    
    // 全動画に対してイベントマップを作成
    for (final video in allVideos) {
      final day = DateTime(video.publishedAt.year, video.publishedAt.month, video.publishedAt.day);
      
      if (!eventMap.containsKey(day)) {
        eventMap[day] = [
          CalendarEvent(
            id: 'event-${day.toIso8601String()}',
            date: day,
            videos: [video],
          )
        ];
      } else {
        // 既存のイベントに動画を追加
        final existingEvent = eventMap[day]![0];
        final updatedVideos = [...existingEvent.videos, video];
        eventMap[day] = [
          existingEvent.copyWith(videos: updatedVideos),
        ];
      }
    }
    
    _cachedEvents = eventMap;
    
    // 指定された月のイベントのみを返す
    final Map<DateTime, List<CalendarEvent>> monthEvents = {};
    eventMap.forEach((day, events) {
      if (day.year == month.year && day.month == month.month) {
        monthEvents[day] = events;
      }
    });
    
    debugPrint('${month.year}年${month.month}月のイベント数: ${monthEvents.length}');
    return monthEvents;
  }
  
  /// Get event counts for the entire month (用ビジュアルマーカー)
  static Future<Map<DateTime, int>> getEventCountsForMonth(DateTime month) async {
    final events = await getEventsForMonth(month);
    final Map<DateTime, int> countMap = {};
    
    events.forEach((day, dayEvents) {
      countMap[day] = dayEvents.fold<int>(0, (count, event) => count + event.videos.length);
    });
    
    // デバッグログ出力
    int totalVideos = 0;
    countMap.forEach((day, count) {
      totalVideos += count;
    });
    
    debugPrint('${month.year}年${month.month}月のイベント数: ${countMap.length}, 合計動画数: $totalVideos');
    return countMap;
  }
}

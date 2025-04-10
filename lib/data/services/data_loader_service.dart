import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/domain/models/calendar_event.dart';
import 'package:marle_stream_history/data/services/database_service.dart';
import 'package:marle_stream_history/data/services/csv_parser_service.dart';
import 'package:marle_stream_history/data/services/data_source.dart';
import 'package:marle_stream_history/domain/services/settings_service.dart';

/// Service for loading data from JSON files
class DataLoaderService {
  /// Specifies the source for loading videos
  static DataSource dataSource = DataSource.json;

  /// Path to the CSV file
  static String csvPath = 'assets/data/csv/videos.csv';

  /// Path to the JSON file
  static String jsonPath = 'assets/data/initial_videos.json';

  /// キャッシュしたビデオリスト
  static List<YoutubeVideo>? _cachedVideos;

  /// 読み込み中かどうかのフラグ
  static bool _isLoading = false;

  /// 一度に読み込むビデオの最大数
  static const int _maxVideosPerLoad = 20;

  /// Load videos from configured data source
  static Future<List<YoutubeVideo>> loadVideos() async {
    try {
      final db = DatabaseService.instance;
      
      // キャッシュがあればそれを返す
      if (_cachedVideos != null && _cachedVideos!.isNotEmpty) {
        debugPrint('Returning cached videos: ${_cachedVideos!.length} videos');
        return _cachedVideos!;
      }

      // 読み込み中ならデータベースから直接取得
      if (_isLoading) {
        debugPrint('Loading is in progress, fetching from database');
        return await db.getAllVideos();
      }

      // データソースに応じてロード処理を切り替え
      _isLoading = true;
      try {
        switch (dataSource) {
          case DataSource.json:
            _cachedVideos = await _loadVideosFromJson();
            break;
          case DataSource.csv:
            _cachedVideos = await _loadVideosFromCsv();
            break;
        }
        
        if (_cachedVideos == null || _cachedVideos!.isEmpty) {
          debugPrint('Failed to load videos from source, fetching from database');
          _cachedVideos = await db.getAllVideos();
        }
        
        // 日付で降順にソート
        _cachedVideos!.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        return _cachedVideos!;
      } finally {
        _isLoading = false;
      }
    } catch (e) {
      debugPrint('Critical error in loadVideos(): $e');
      return [];
    }
  }

  /// Load videos from CSV file
  static Future<List<YoutubeVideo>> _loadVideosFromCsv() async {
    try {
      final videos = await CsvParserService.loadVideosFromCsv(csvPath);
      debugPrint('Loaded ${videos.length} videos from CSV');
      return videos;
    } catch (e) {
      debugPrint('Error loading videos from CSV: $e');
      return [];
    }
  }
  
  /// Load videos from initial data JSON file
  static Future<List<YoutubeVideo>> _loadVideosFromJson() async {
    try {
      final db = DatabaseService.instance;
      
      // JSONからデータを読み込む
      debugPrint('Loading videos from JSON...');
      final jsonString = await rootBundle.loadString(jsonPath);
      final List<YoutubeVideo> videos = await compute(_parseJsonVideos, jsonString);
      
      // データベースをクリアしてから保存
      try {
        debugPrint('Clearing database...');
        await db.clearDatabase();
        
        debugPrint('Inserting ${videos.length} videos to database...');
        await db.insertVideos(videos);
        
        // 通知のスケジュール（もし通知サービスが存在する場合）
        /* // Removed NotificationService related code
        final settingsService = SettingsService();
        await settingsService.init();
        if (settingsService.enableNotifications) {
          await NotificationService.instance.init(settingsService);
          await NotificationService.instance.scheduleAllAnniversaries(videos);
        }
        */

        debugPrint('初期データのロードと通知スケジューリングが完了しました。');
      } catch (e) {
        debugPrint('Error saving to database: $e');
      }
      
      return videos;
    } catch (e) {
      debugPrint('Error loading videos from JSON: $e');
      return [];
    }
  }

  /// Parse JSON data in a separate isolate
  static List<YoutubeVideo> _parseJsonVideos(String jsonString) {
    try {
      // Parse the JSON
      final List<dynamic> jsonData = json.decode(jsonString);
      
      // Convert to YoutubeVideo objects
      final videos = jsonData.map((videoJson) {
        // Make sure viewCount and likeCount are doubles
        final Map<String, dynamic> fixedJson = Map.from(videoJson);
        
        // Normalize numeric fields
        fixedJson['viewCount'] = _normalizeNumeric(fixedJson['viewCount']);
        fixedJson['likeCount'] = _normalizeNumeric(fixedJson['likeCount']);
        
        // Ensure tags is a list
        fixedJson['tags'] = _normalizeTags(fixedJson['tags']);
        
        return YoutubeVideo.fromJson(fixedJson);
      }).toList();
      
      return videos;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return [];
    }
  }

  /// Normalize numeric values to double
  static double _normalizeNumeric(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Normalize tags to a list of strings
  static List<String> _normalizeTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) {
      // Ensure each tag is a non-empty string
      return tags.map((tag) => tag.toString().trim())
                .where((tag) => tag.isNotEmpty)
                .toList();
    }
    if (tags is String) {
      // Split comma-separated tags and filter empty ones
      return tags.split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();
    }
    return [];
  }

  /// Load a subset of videos (for pagination)
  static Future<List<YoutubeVideo>> loadVideosWithPagination(int page) async {
    final allVideos = await loadVideos();
    
    final startIndex = page * _maxVideosPerLoad;
    if (startIndex >= allVideos.length) {
      return [];
    }
    
    final endIndex = (startIndex + _maxVideosPerLoad) > allVideos.length 
        ? allVideos.length 
        : startIndex + _maxVideosPerLoad;
    
    return allVideos.sublist(startIndex, endIndex);
  }
  
  /// Extract all unique tags from videos
  static Future<List<String>> extractAllTags() async {
    final videos = await loadVideos();
    final tagsSet = <String>{};
    
    for (final video in videos) {
      tagsSet.addAll(video.tags);
    }
    
    final allTags = tagsSet.toList()..sort();
    return allTags;
  }

  /// Clear the cache to force reload
  static void clearCache() {
    _cachedVideos = null;
    debugPrint('Video cache cleared');
  }

  /// 総再生回数を計算
  static Future<double> getTotalViewCount() async {
    final videos = await loadVideos();
    return videos.fold<double>(0.0, (sum, video) => sum + video.viewCount);
  }

  /// 総配信数を取得
  static Future<int> getTotalVideoCount() async {
    final videos = await loadVideos();
    return videos.length;
  }
  
  /// 日付ごとに動画をグループ化
  static Future<Map<DateTime, List<CalendarEvent>>> groupVideosByDate() async {
    final videos = await loadVideos();
    final result = <DateTime, List<CalendarEvent>>{};
    
    // 日付の比較用の関数を定義
    bool isSameDay(DateTime a, DateTime b) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }
    
    // 動画を公開日でソート (昇順)
    videos.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
    debugPrint('動画総数: ${videos.length}件');
    
    int processedCount = 0;
    
    // 各ビデオを日付でグループ化
    for (final video in videos) {
      // 日付部分のみを抽出 (時間を無視して日付のみにする)
      final date = DateTime(
        video.publishedAt.year, 
        video.publishedAt.month, 
        video.publishedAt.day
      );
      
      // 日付に対応するイベントを検索・追加
      bool dateFound = false;
      for (final key in result.keys) {
        if (isSameDay(key, date)) {
          // 既存のイベントリストを取得
          final eventsList = result[key]!;
          
          // 既存のイベントリストが空でない場合は最初のイベントを取得
          if (eventsList.isNotEmpty) {
            // ここで新しいイベントを生成して置き換え（不変リストを変更するのではなく）
            final currentEvent = eventsList.first;
            final updatedVideos = List<YoutubeVideo>.from(currentEvent.videos)..add(video);
            
            // 新しいビデオリストで更新されたイベントを作成
            final updatedEvent = currentEvent.copyWith(videos: updatedVideos);
            
            // イベントリストを更新
            result[key] = [updatedEvent];
          } else {
            // イベントリストが空の場合（通常発生しないはず）は新しいイベントを作成
            result[key] = [
              CalendarEvent(
                id: '${date.year}-${date.month}-${date.day}',
                date: date,
                videos: [video],
              )
            ];
          }
          
          dateFound = true;
          break;
        }
      }
      
      // 新しい日付の場合は新規イベント作成
      if (!dateFound) {
        result[date] = [
          CalendarEvent(
            id: '${date.year}-${date.month}-${date.day}',
            date: date,
            videos: [video],
          )
        ];
      }
      
      processedCount++;
      if (processedCount % 10 == 0) {
        debugPrint('$processedCount 件の動画を処理しました');
      }
    }
    
    debugPrint('グループ化されたイベント数: ${result.length}');
    
    // デバッグ出力
    result.forEach((date, events) {
      debugPrint('日付: ${date.year}/${date.month}/${date.day} - 動画数: ${events.first.videos.length}');
    });
    
    return result;
  }

  /// デバッグ用: データベース内の動画数を表示
  static Future<void> debugDatabaseCount() async {
    try {
      final db = DatabaseService.instance;
      final count = await db.getVideoCount();
      debugPrint('データベース内の動画数: $count');
    } catch (e) {
      debugPrint('デバッグエラー: $e');
    }
  }
  
  /// 特定の日付のイベントを取得する
  static Future<List<CalendarEvent>> getEventsForDay(DateTime day) async {
    try {
      // 1. すべての日付のイベントを取得
      final allEvents = await groupVideosByDate();
      
      // 2. 時間情報を除いた日付オブジェクトを作成
      final normalizedDay = DateTime(day.year, day.month, day.day);
      
      // 3. 指定された日付と一致するイベントを検索
      for (final key in allEvents.keys) {
        if (key.year == normalizedDay.year && 
            key.month == normalizedDay.month && 
            key.day == normalizedDay.day) {
          final events = allEvents[key] ?? [];
          debugPrint('日付 ${normalizedDay.year}/${normalizedDay.month}/${normalizedDay.day} のイベント数: ${events.length}件');
          return events;
        }
      }
      
      // 4. 見つからなかった場合は空リストを返す
      debugPrint('日付 ${normalizedDay.year}/${normalizedDay.month}/${normalizedDay.day} のイベントは見つかりませんでした');
      return [];
    } catch (e) {
      debugPrint('特定日のイベント取得エラー: $e');
      return [];
    }
  }
}
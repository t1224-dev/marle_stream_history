import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:csv/csv.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';

/// CSVファイルをインポートするためのサービス
class CsvImporterService {
  /// CSVファイルを選択し、YouTubeVideoオブジェクトのリストとして読み込む
  static Future<List<YoutubeVideo>?> importVideosFromCsv(BuildContext context) async {
    try {
      // ファイル選択ダイアログを表示
      final XTypeGroup csvTypeGroup = XTypeGroup(
        label: 'CSV',
        extensions: ['csv'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [csvTypeGroup],
      );
      
      if (file == null) {
        debugPrint('No file selected');
        return null;
      }
      
      // ファイルの内容を読み込む
      final String fileContent = await file.readAsString();
      
      // CSVをパース
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(fileContent);
      
      if (csvTable.isEmpty || csvTable.length <= 1) {
        debugPrint('CSV file is empty or contains only headers');
        return null;
      }
      
      // ヘッダー行をスキップ
      final headers = csvTable[0];
      final List<YoutubeVideo> videos = [];
      
      // 各行をYouTubeVideoオブジェクトに変換
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length < headers.length) continue;
        
        try {
          final video = _createVideoFromCsvRow(row, headers, i);
          videos.add(video);
        } catch (e) {
          debugPrint('Error parsing CSV row: $e');
        }
      }
      
      // 日付でソート
      videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      return videos;
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      return null;
    }
  }
  
  /// CSV行からYouTubeVideoオブジェクトを作成
  static YoutubeVideo _createVideoFromCsvRow(
    List<dynamic> row, 
    List<dynamic> headers, 
    int index
  ) {
    // CSVの列インデックスを取得（ヘッダー名で検索）
    final titleIndex = headers.indexOf('title');
    final viewCountIndex = headers.indexOf('viewCount');
    final likeCountIndex = headers.indexOf('likeCount');
    final videoUrlIndex = headers.indexOf('videoUrl');
    final publishedAtIndex = headers.indexOf('publishedAt');
    final durationIndex = headers.indexOf('duration');
    final thumbnailIdIndex = headers.indexOf('thumbnailId');
    
    // 必須フィールドの存在確認
    if (titleIndex < 0 || videoUrlIndex < 0 || publishedAtIndex < 0) {
      throw Exception('Required column not found in CSV');
    }
    
    return YoutubeVideo(
      id: index.toString(),
      videoId: _extractVideoId(row[videoUrlIndex].toString()),
      title: row[titleIndex].toString(),
      viewCount: viewCountIndex >= 0 ? _parseDouble(row[viewCountIndex]) : 0,
      likeCount: likeCountIndex >= 0 ? _parseDouble(row[likeCountIndex]) : 0,
      videoUrl: row[videoUrlIndex].toString(),
      publishedAt: _parseDateTime(row[publishedAtIndex].toString()),
      duration: durationIndex >= 0 ? row[durationIndex].toString() : '',
      thumbnailId: thumbnailIdIndex >= 0 ? row[thumbnailIdIndex].toString() : '',
      thumbnailPath: thumbnailIdIndex >= 0 
          ? 'assets/images/thumbnails/${row[thumbnailIdIndex]}.jpg' 
          : '',
      description: '',
      archiveUrl: '',
      isFavorite: false,
      tags: _extractTagsFromTitle(row[titleIndex].toString()),
    );
  }
  
  /// YouTube URLからビデオIDを抽出
  static String _extractVideoId(String url) {
    final RegExp regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([a-zA-Z0-9_-]+)',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }
  
  /// 文字列から数値を安全にパース
  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (e) {
      return 0;
    }
  }
  
  /// 文字列から日時をパース
  static DateTime _parseDateTime(String dateString) {
    try {
      // フォーマットに応じて適切にパース
      if (dateString.contains('/')) {
        // Format: 2023/08/31 20:00:09
        final parts = dateString.split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
        
        return DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
        );
      } else {
        // ISO形式を試行
        return DateTime.parse(dateString);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return DateTime.now();
    }
  }
  
  /// タイトルからタグを抽出
  static List<String> _extractTagsFromTitle(String title) {
    final List<String> tags = [];
    
    // タイトルから【】で囲まれた部分をタグとして抽出
    final RegExp tagRegex = RegExp(r'【(.*?)】');
    final Iterable<RegExpMatch> matches = tagRegex.allMatches(title);
    
    for (final match in matches) {
      final tag = match.group(1);
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }
    
    return tags;
  }
} 
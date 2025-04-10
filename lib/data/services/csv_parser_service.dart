import 'package:flutter/services.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:flutter/foundation.dart';

/// Service for parsing CSV data and converting to model objects
class CsvParserService {
  /// Load and parse videos from CSV file
  static Future<List<YoutubeVideo>> loadVideosFromCsv(String assetPath) async {
    try {
      // Load the CSV file from assets
      final csvString = await rootBundle.loadString(assetPath);
      
      // Parse the CSV
      final List<YoutubeVideo> videos = await compute(_parseCsv, csvString);
      
      // Sort videos by date, most recent first
      videos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      return videos;
    } catch (e) {
      debugPrint('Error loading videos from CSV: $e');
      return [];
    }
  }
  
  /// Parse CSV data in an isolate
  static List<YoutubeVideo> _parseCsv(String csvString) {
    final List<YoutubeVideo> videos = [];
    
    // Split into lines
    final lines = csvString.split('\n');
    
    // Skip header
    if (lines.length <= 1) return [];
    
    // Parse each line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      try {
        // Split by comma, but handle commas within quotes
        final List<String> columns = _splitCsvLine(line);
        
        if (columns.length < 7) continue; // Skip invalid lines
        
        // Create YoutubeVideo object
        final video = YoutubeVideo(
          id: i.toString(), // Use index as ID
          videoId: columns[6].trim(), // サムネイルIDをvideoIdとして使用
          title: columns[0].trim(),
          viewCount: double.tryParse(columns[1].trim()) ?? 0,
          likeCount: double.tryParse(columns[2].trim()) ?? 0,
          videoUrl: columns[3].trim(),
          publishedAt: _parseDateTime(columns[4].trim()),
          duration: columns[5].trim(),
          thumbnailId: columns[6].trim(),
          thumbnailPath: 'assets/images/thumbnails/${columns[6].trim()}.jpg',
          description: '',
          archiveUrl: '',
          isFavorite: false,
          // タイトルから適当にタグを生成（実際の実装では改善が必要）
          tags: _extractTagsFromTitle(columns[0]),
        );
        
        videos.add(video);
      } catch (e) {
        debugPrint('Error parsing CSV line: $e');
      }
    }
    
    return videos;
  }
  
  /// Split CSV line handling commas within quotes
  static List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    String current = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }
    
    // Add the last field
    if (current.isNotEmpty) {
      result.add(current);
    }
    
    return result;
  }
  
  /// Parse date time from string
  static DateTime _parseDateTime(String dateString) {
    try {
      // Format: 2023/08/31 20:00:09
      final parts = dateString.split(' ');
      final dateParts = parts[0].split('/');
      final timeParts = parts[1].split(':');
      
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return DateTime.now();
    }
  }
  
  /// Extract tags from title
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

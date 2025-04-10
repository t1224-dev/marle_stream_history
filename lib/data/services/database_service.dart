import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';

class DatabaseService {
  static const String _databaseName = 'marle_videos.db';
  static const int _databaseVersion = 2;  // Increment version to force migration

  // シングルトンインスタンス
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      debugPrint('Database connection established successfully');
      return _database!;
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future _createDatabase(Database db, int version) async {
    debugPrint('Creating database tables...');
    
    // Videos table
    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        videoId TEXT NOT NULL,
        publishedAt TEXT NOT NULL,
        title TEXT NOT NULL,
        thumbnailPath TEXT NOT NULL,
        description TEXT,
        videoUrl TEXT NOT NULL,
        duration TEXT,
        viewCount REAL,
        likeCount REAL,
        thumbnailId TEXT,
        archiveUrl TEXT,
        isFavorite INTEGER DEFAULT 0,
        customNotes TEXT
      )
    ''');

    // Tags table (many-to-many relation)
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        videoId TEXT NOT NULL,
        tag TEXT NOT NULL,
        FOREIGN KEY (videoId) REFERENCES videos (id)
      )
    ''');

    debugPrint('Database tables created successfully');
  }

  // Database upgrade method
  Future _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from $oldVersion to $newVersion');
    if (oldVersion < 2) {
      // Example migration: add a new column or modify schema
      // await db.execute('ALTER TABLE videos ADD COLUMN new_column TEXT');
    }
  }

  // Insert videos with robust error handling
  Future<void> insertVideos(List<YoutubeVideo> videos) async {
    try {
      final db = await instance.database;
      final batch = db.batch();

      for (final video in videos) {
        batch.insert('videos', {
          'id': video.id,
          'videoId': video.videoId,
          'publishedAt': video.publishedAt.toIso8601String(),
          'title': video.title,
          'thumbnailPath': video.thumbnailPath,
          'description': video.description,
          'videoUrl': video.videoUrl,
          'duration': video.duration,
          'viewCount': video.viewCount,
          'likeCount': video.likeCount,
          'thumbnailId': video.thumbnailId,
          'archiveUrl': video.archiveUrl,
          'isFavorite': video.isFavorite ? 1 : 0,
          'customNotes': video.customNotes,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // タグを挿入
        for (final tag in video.tags) {
          batch.insert('tags', {
            'videoId': video.id,
            'tag': tag,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      final results = await batch.commit(noResult: false);
      debugPrint('Inserted ${videos.length} videos. Batch results: $results');
    } catch (e) {
      debugPrint('Error inserting videos: $e');
      rethrow;
    }
  }

  // 日付範囲で動画を取得
  Future<List<YoutubeVideo>> getVideosByDateRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    try {
      final videos = await db.query(
        'videos', 
        where: 'publishedAt BETWEEN ? AND ?',
        whereArgs: [
          start.toIso8601String(), 
          end.toIso8601String()
        ]
      );
      final tags = await db.query('tags');

      return videos.map((videoMap) {
        final videoTags = tags
            .where((tag) => tag['videoId'] == videoMap['id'])
            .map((tag) => tag['tag'] as String)
            .toList();

        return YoutubeVideo(
          id: videoMap['id'] as String,
          videoId: videoMap['videoId'] as String,
          publishedAt: DateTime.parse(videoMap['publishedAt'] as String),
          title: videoMap['title'] as String,
          thumbnailPath: videoMap['thumbnailPath'] as String,
          description: videoMap['description'] as String,
          videoUrl: videoMap['videoUrl'] as String,
          duration: videoMap['duration'] as String,
          viewCount: videoMap['viewCount'] as double,
          likeCount: videoMap['likeCount'] as double,
          thumbnailId: videoMap['thumbnailId'] as String,
          archiveUrl: videoMap['archiveUrl'] as String,
          isFavorite: videoMap['isFavorite'] == 1,
          tags: videoTags,
          customNotes: videoMap['customNotes'] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting videos by date range: $e');
      return [];
    }
  }

  /// Get all videos from the database
  Future<List<YoutubeVideo>> getAllVideos() async {
    try {
      final db = await database;
      final videos = await db.query('videos', orderBy: 'publishedAt DESC');
      final tags = await db.query('tags');

      final processedVideos = videos.map((videoMap) {
        final videoTags = tags
            .where((tag) => tag['videoId'] == videoMap['id'])
            .map((tag) => tag['tag'] as String)
            .toList();

        return YoutubeVideo(
          id: videoMap['id'] as String,
          videoId: videoMap['videoId'] as String,
          publishedAt: DateTime.parse(videoMap['publishedAt'] as String),
          title: videoMap['title'] as String,
          thumbnailPath: videoMap['thumbnailPath'] as String,
          description: videoMap['description'] as String,
          videoUrl: videoMap['videoUrl'] as String,
          duration: videoMap['duration'] as String,
          viewCount: videoMap['viewCount'] as double,
          likeCount: videoMap['likeCount'] as double,
          thumbnailId: videoMap['thumbnailId'] as String,
          archiveUrl: videoMap['archiveUrl'] as String,
          isFavorite: videoMap['isFavorite'] == 1,
          tags: videoTags,
          customNotes: videoMap['customNotes'] as String,
        );
      }).toList();

      debugPrint('Retrieved ${processedVideos.length} videos from database');
      return processedVideos;
    } catch (e) {
      debugPrint('Error retrieving videos: $e');
      return [];
    }
  }
  
  /// Get a video by its ID
  Future<YoutubeVideo?> getVideoById(String videoId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> videos = await db.query(
        'videos',
        where: 'videoId = ?',
        whereArgs: [videoId],
        limit: 1,
      );
      
      if (videos.isEmpty) {
        return null;
      }
      
      final videoMap = videos.first;
      final tags = await db.query(
        'tags',
        where: 'videoId = ?',
        whereArgs: [videoMap['id']],
      );
      
      final videoTags = tags
          .map((tag) => tag['tag'] as String)
          .toList();
      
      return YoutubeVideo(
        id: videoMap['id'] as String,
        videoId: videoMap['videoId'] as String,
        publishedAt: DateTime.parse(videoMap['publishedAt'] as String),
        title: videoMap['title'] as String,
        thumbnailPath: videoMap['thumbnailPath'] as String,
        description: videoMap['description'] as String,
        videoUrl: videoMap['videoUrl'] as String,
        duration: videoMap['duration'] as String,
        viewCount: videoMap['viewCount'] as double,
        likeCount: videoMap['likeCount'] as double,
        thumbnailId: videoMap['thumbnailId'] as String,
        archiveUrl: videoMap['archiveUrl'] as String,
        isFavorite: videoMap['isFavorite'] == 1,
        tags: videoTags,
        customNotes: videoMap['customNotes'] as String,
      );
    } catch (e) {
      debugPrint('Error retrieving video by ID: $e');
      return null;
    }
  }

  // データベースにデータがあるか確認
  Future<bool> hasData() async {
    try {
      final db = await instance.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM videos')
      );
      debugPrint('Database video count: $count');
      return count != null && count > 0;
    } catch (e) {
      debugPrint('Error checking database data: $e');
      return false;
    }
  }

  // データベースをクリア
  Future<void> clearDatabase() async {
    try {
      final db = await instance.database;
      await db.delete('videos');
      await db.delete('tags');
      debugPrint('Database cleared successfully');
    } catch (e) {
      debugPrint('Error clearing database: $e');
      rethrow;
    }
  }

  // 動画の総数を取得
  Future<int> getVideoCount() async {
    try {
      final db = await instance.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM videos')
      );
      debugPrint('Total video count: $count');
      return count ?? 0;
    } catch (e) {
      debugPrint('Error getting video count: $e');
      return 0;
    }
  }
}

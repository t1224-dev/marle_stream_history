/// Model class representing a YouTube video
class YoutubeVideo {
  /// The video ID
  final String id;
  
  /// YouTube video ID
  final String videoId;
  
  /// Video publication date
  final DateTime publishedAt;
  
  /// Video title
  final String title;
  
  /// Path to the thumbnail image
  final String thumbnailPath;
  
  /// Video description
  final String description;
  
  /// URL to the video
  final String videoUrl;
  
  /// Video duration
  final String duration;
  
  /// View count
  final double viewCount;
  
  /// Like count
  final double likeCount;
  
  /// Thumbnail ID
  final String thumbnailId;
  
  /// URL to the archive version (if available)
  final String archiveUrl;
  
  /// Whether the video is marked as favorite
  bool isFavorite;
  
  /// Tags associated with the video
  final List<String> tags;
  
  /// User custom notes for this video
  String customNotes;

  /// Constructor
  YoutubeVideo({
    required this.id,
    required this.videoId,
    required this.publishedAt,
    required this.title,
    required this.thumbnailPath,
    required this.description,
    required this.videoUrl,
    required this.duration,
    required this.viewCount,
    required this.likeCount,
    required this.thumbnailId,
    this.archiveUrl = '',
    this.isFavorite = false,
    this.tags = const [],
    this.customNotes = '',
  });

  /// Create from JSON
  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    return YoutubeVideo(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      title: json['title'] as String,
      thumbnailPath: json['thumbnailPath'] as String,
      description: json['description'] as String,
      videoUrl: json['videoUrl'] as String,
      duration: json['duration'] as String,
      viewCount: json['viewCount'] as double,
      likeCount: json['likeCount'] as double,
      thumbnailId: json['thumbnailId'] as String,
      archiveUrl: json['archiveUrl'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      customNotes: json['customNotes'] as String? ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'publishedAt': publishedAt.toIso8601String(),
      'title': title,
      'thumbnailPath': thumbnailPath,
      'description': description,
      'videoUrl': videoUrl,
      'duration': duration,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'thumbnailId': thumbnailId,
      'archiveUrl': archiveUrl,
      'isFavorite': isFavorite,
      'tags': tags,
      'customNotes': customNotes,
    };
  }

  /// Create a copy of this video with updated properties
  YoutubeVideo copyWith({
    String? id,
    String? videoId,
    DateTime? publishedAt,
    String? title,
    String? thumbnailPath,
    String? description,
    String? videoUrl,
    String? duration,
    double? viewCount,
    double? likeCount,
    String? thumbnailId,
    String? archiveUrl,
    bool? isFavorite,
    List<String>? tags,
    String? customNotes,
  }) {
    return YoutubeVideo(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      publishedAt: publishedAt ?? this.publishedAt,
      title: title ?? this.title,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      thumbnailId: thumbnailId ?? this.thumbnailId,
      archiveUrl: archiveUrl ?? this.archiveUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      customNotes: customNotes ?? this.customNotes,
    );
  }
}

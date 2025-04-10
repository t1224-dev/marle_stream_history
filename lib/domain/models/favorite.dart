/// Model class representing a favorite video
class Favorite {
  /// ID of the video that is marked as a favorite
  final String videoId;
  
  /// Date when the video was added to favorites
  final DateTime addedAt;
  
  /// Custom note added by the user for this favorite video
  String customNote;

  /// Constructor
  Favorite({
    required this.videoId,
    required this.addedAt,
    this.customNote = '',
  });

  /// Create from JSON
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      videoId: json['videoId'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      customNote: json['customNote'] as String? ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'addedAt': addedAt.toIso8601String(),
      'customNote': customNote,
    };
  }

  /// Create a copy of this favorite with updated properties
  Favorite copyWith({
    String? videoId,
    DateTime? addedAt,
    String? customNote,
  }) {
    return Favorite(
      videoId: videoId ?? this.videoId,
      addedAt: addedAt ?? this.addedAt,
      customNote: customNote ?? this.customNote,
    );
  }
}

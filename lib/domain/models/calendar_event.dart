import 'package:marle_stream_history/domain/models/youtube_video.dart';

/// Model class representing a calendar event with associated videos
class CalendarEvent {
  /// The event ID
  final String id;
  
  /// Date of the event
  final DateTime date;
  
  /// Videos associated with this event
  final List<YoutubeVideo> videos;

  /// Constructor
  CalendarEvent({
    required this.id,
    required this.date,
    this.videos = const [],
  });

  /// Create from JSON
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      videos: (json['videos'] as List<dynamic>?)
              ?.map((e) => YoutubeVideo.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'videos': videos.map((video) => video.toJson()).toList(),
    };
  }

  /// Create a copy of this event with updated properties
  CalendarEvent copyWith({
    String? id,
    DateTime? date,
    List<YoutubeVideo>? videos,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      videos: videos ?? this.videos,
    );
  }
}

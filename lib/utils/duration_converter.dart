/// Utility class for converting video duration strings to seconds
class DurationConverter {
  /// Convert duration string (HH:MM:SS or MM:SS) to total seconds
  static int durationToSeconds(String duration) {
    final parts = duration.split(':');

    if (parts.length == 3) {
      // HH:MM:SS format
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final seconds = int.parse(parts[2]);
      return hours * 3600 + minutes * 60 + seconds;
    } else if (parts.length == 2) {
      // MM:SS format
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      return minutes * 60 + seconds;
    } else {
      // Invalid format, return 0
      return 0;
    }
  }
}

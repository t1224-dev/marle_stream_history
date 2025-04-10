import 'package:flutter/material.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';

/// A horizontally scrollable list of videos
class HorizontalVideoList extends StatelessWidget {
  /// The list of videos to display
  final List<YoutubeVideo> videos;

  /// Function to call when a video is tapped
  final Function(YoutubeVideo)? onVideoTap;

  /// Constructor
  const HorizontalVideoList({super.key, required this.videos, this.onVideoTap});

  @override
  Widget build(BuildContext context) {
    // 幅を制限して右側のオーバーフローを防止
    return SizedBox(
      height: 250, // 元の高さに戻す
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ), // パディングを小さくして右側のオーバーフローを防止
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return SizedBox(
            width: 240, // 幅をさらに小さくして右側のオーバーフローを防止
            child: VideoCard(
              video: video,
              onTap: () => onVideoTap?.call(video),
            ),
          );
        },
      ),
    );
  }
}

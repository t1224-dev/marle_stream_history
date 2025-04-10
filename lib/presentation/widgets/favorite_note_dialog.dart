import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';

/// Dialog for entering or editing a note for a favorite video
class FavoriteNoteDialog extends StatefulWidget {
  /// The video to add a note to
  final YoutubeVideo video;

  /// Constructor
  const FavoriteNoteDialog({super.key, required this.video});

  @override
  State<FavoriteNoteDialog> createState() => _FavoriteNoteDialogState();
}

class _FavoriteNoteDialogState extends State<FavoriteNoteDialog> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();

    // Initialize with existing note if any
    final favoriteService = Provider.of<FavoriteService>(
      context,
      listen: false,
    );
    final favorite = favoriteService.getFavorite(widget.video.videoId);

    _noteController = TextEditingController(text: favorite?.customNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('お気に入りのメモ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.video.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'メモを入力（任意）',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () async {
            final favoriteService = Provider.of<FavoriteService>(
              context,
              listen: false,
            );
            final favorite = favoriteService.getFavorite(widget.video.videoId);

            if (favorite != null) {
              // Update existing note
              await favoriteService.updateNote(
                widget.video.videoId,
                _noteController.text,
              );
            } else {
              // Add new favorite with note
              await favoriteService.addFavorite(
                widget.video,
                customNote: _noteController.text,
              );
            }

            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

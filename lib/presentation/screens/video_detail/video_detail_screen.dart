import 'package:flutter/material.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';
import 'package:marle_stream_history/utils/date_formatter.dart';
import 'package:marle_stream_history/data/video_data_manager.dart';
import 'package:marle_stream_history/domain/services/video_service.dart';
import 'package:marle_stream_history/domain/services/settings_service.dart';
import 'package:marle_stream_history/domain/services/favorite_service.dart';
import 'package:marle_stream_history/presentation/widgets/favorite_note_dialog.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

/// Screen that displays detailed information about a YouTube video
class VideoDetailScreen extends StatefulWidget {
  /// The video to display
  final YoutubeVideo video;

  /// Constructor
  const VideoDetailScreen({super.key, required this.video});

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  bool _isFavorite = false;
  bool _showArchiveSection = false;
  String? _favoriteNote;

  // すべての動画データを取得するためのFuture
  late Future<List<YoutubeVideo>> _allVideosFuture;

  // 関連動画のキャッシュ
  List<YoutubeVideo>? _relatedVideosCache;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.video.isFavorite;

    // すべての動画データを取得
    _allVideosFuture = VideoDataManager.getVideos();

    // 非同期で設定をロードする(検知後に実行)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadFavoriteNote();
    });
  }

  /// 設定をロード
  void _loadSettings() {
    if (!mounted) return;
    try {
      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );
      setState(() {
        _showArchiveSection = settingsService.enableArchiveUrls;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// お気に入りのメモを読み込む
  void _loadFavoriteNote() {
    if (!mounted) return;
    try {
      final favoriteService = Provider.of<FavoriteService>(
        context,
        listen: false,
      );
      final favorite = favoriteService.getFavorite(widget.video.videoId);

      setState(() {
        _favoriteNote = favorite?.customNote;
        _isFavorite = favoriteService.isFavorite(widget.video.videoId);
      });
    } catch (e) {
      debugPrint('Error loading favorite note: $e');
    }
  }

  /// Toggle favorite status
  Future<void> _toggleFavorite() async {
    // Use FavoriteService
    final favoriteService = Provider.of<FavoriteService>(
      context,
      listen: false,
    );
    final currentVideoId = widget.video.videoId; // 現在の動画IDを保持

    if (_isFavorite) {
      // ノートを表示して確認
      final shouldRemove = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('お気に入りから削除'),
              content: const Text('本当にお気に入りから削除しますか？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('削除'),
                ),
              ],
            ),
      );

      if (shouldRemove != true) return;

      // Remove from favorites
      await favoriteService.removeFavorite(currentVideoId); // videoIdを使用
      
      // 元の動画オブジェクトのisFavorite状態も更新
      widget.video.isFavorite = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りから削除しました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Show note dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => FavoriteNoteDialog(video: widget.video),
      );

      // 追加処理はFavoriteNoteDialog内で行われるため、ここでは何もしない
      if (result != true) return;
      
      // 元の動画オブジェクトのisFavorite状態も更新
      widget.video.isFavorite = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('お気に入りに追加しました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Update state by reloading from service
    if (mounted) {
      // サービスから最新の状態とメモを再読み込み
      _loadFavoriteNote();
    }
  }

  /// Edit favorite note
  Future<void> _editFavoriteNote() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FavoriteNoteDialog(video: widget.video),
    );

    if (result == true && mounted) {
      // サービスから最新の状態とメモを再読み込み
      _loadFavoriteNote();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモを更新しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Open the YouTube video
  Future<void> _openYouTube() async {
    // アーカイブURLが無効の場合はYouTubeを開かない
    if (!_showArchiveSection) {
      // アーカイブ機能が無効の場合はアクセスできない旨を表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この機能は現在利用できません'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await VideoService.openYouTube(widget.video, context: context);
  }

  final GlobalKey _shareButtonKey = GlobalKey();

  /// Share the video with thumbnail
  Future<void> _shareVideo() async {
    final RenderBox? box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;

    final video = widget.video;
    final message =
        '${DateFormat('yyyy年MM月dd日').format(video.publishedAt)}に'
        'マール・アストレアさんが配信しました\n${video.title}\n#マールの軌跡';

    try {
      // サムネイルのパスを正規化（空かスラッシュで終わる場合はデフォルト画像を使用）
      final String thumbnailAssetPath = video.thumbnailPath.isNotEmpty && !video.thumbnailPath.endsWith('/')
          ? (video.thumbnailPath.startsWith('assets/')
              ? video.thumbnailPath
              : 'assets/${video.thumbnailPath}')
          : ''; // not_found.jpg の代わりに空の文字列を使用

      // デフォルト画像の判定方法を変更
      final bool useDefaultThumbnail = thumbnailAssetPath.isEmpty;
      
      if (useDefaultThumbnail) {
        await Share.share(
          message,
          subject: 'マール・アストレア 配信アーカイブ',
          sharePositionOrigin:
              box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
        return;
      }

      try {
        // アセットから一時ファイルを作成
        final ByteData data = await rootBundle.load(thumbnailAssetPath);
        final Directory tempDir = await getTemporaryDirectory();
        final String tempPath = '${tempDir.path}/marle_${video.videoId}.jpg';
        final File tempFile = File(tempPath);

        // ByteDataをファイルに書き込む
        await tempFile.writeAsBytes(data.buffer.asUint8List());

        if (await tempFile.exists()) {
          // 一時ファイルとして保存したサムネイルを共有
          final files = <XFile>[
            XFile(
              tempPath,
              mimeType: 'image/jpeg',
              name: 'marle_${video.videoId}.jpg',
            ),
          ];

          await Share.shareXFiles(
            files,
            text: message,
            subject: 'マール・アストレア 配信アーカイブ',
            sharePositionOrigin:
                box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );

          // 共有後に一時ファイルを削除（必要に応じて）
          try {
            await tempFile.delete();
          } catch (e) {
            // 一時ファイル削除のエラーは無視してもよい
            debugPrint('一時ファイル削除エラー: $e');
          }
        } else {
          // サムネイルの一時ファイル作成に失敗した場合はテキストのみを共有
          await Share.share(
            message,
            subject: 'マール・アストレア 配信アーカイブ',
            sharePositionOrigin:
                box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );
        }
      } catch (e) {
        // アセットロードか一時ファイル作成でエラーが発生した場合はテキストのみを共有
        debugPrint('サムネイル一時ファイル作成エラー: $e');
        await Share.share(
          message,
          subject: 'マール・アストレア 配信アーカイブ',
          sharePositionOrigin:
              box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('共有エラー: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Activate archive mode (hidden feature)
  void _activateArchiveMode() {
    try {
      final settingsService = Provider.of<SettingsService>(
        context,
        listen: false,
      );
      final activated = settingsService.handleVersionTap();

      if (activated) {
        setState(() {
          _showArchiveSection = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アーカイブモードが有効になりました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error activating archive mode: $e');
    }
  }

  /// サムネイル画像を表示するウィジェットを構築
  Widget _buildThumbnail(YoutubeVideo video, {BoxFit fit = BoxFit.contain}) {
    String? assetPath;

    try {
      if (video.thumbnailPath.isEmpty || video.thumbnailPath.endsWith('/')) {
        // サムネイルパスが空またはスラッシュで終わる場合はデフォルト画像を使用
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildDefaultThumbnail(video),
        );
      } else {
        assetPath = video.thumbnailPath.startsWith('assets/')
            ? video.thumbnailPath
            : 'assets/${video.thumbnailPath}';
      }

      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          assetPath,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('サムネイル読み込みエラー: $error');
            return _buildDefaultThumbnail(video);
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(seconds: 1),
              curve: Curves.easeOut,
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('サムネイル処理エラー: $e');
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildDefaultThumbnail(video),
      );
    }
  }

  /// デフォルトのサムネイル表示を生成
  Widget _buildDefaultThumbnail(YoutubeVideo video) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, color: Colors.grey[400], size: 32),
            const SizedBox(height: 8),
            Text(
              video.title.isNotEmpty
                  ? video.title.substring(0, math.min(video.title.length, 20))
                  : 'タイトルなし',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build an info row with icon and text
  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 引数で渡された日付をフォーマットして表示用に変換
    final formattedDateTime = DateFormatter.formatDateTime(
      widget.video.publishedAt,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('動画詳細'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            key: _shareButtonKey,
            icon: const Icon(Icons.share),
            onPressed: _shareVideo,
          ),
        ],
      ),
      body: FutureBuilder<List<YoutubeVideo>>(
        future: _allVideosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          final allVideos = snapshot.data ?? [];
          if (allVideos.isEmpty) {
            return const Center(child: Text('動画データが取得できませんでした'));
          }

          // 現在の動画の最新情報を取得
          // ここでは非同期ではなく同期的に処理
          final currentVideo = allVideos.firstWhere(
            (v) => v.videoId == widget.video.videoId,
            orElse: () => widget.video,
          );

          // 現在の動画のタグを更新（初回のみ）
          if (currentVideo.videoId == widget.video.videoId &&
              _relatedVideosCache == null) {
            widget.video.tags.clear();
            widget.video.tags.addAll(currentVideo.tags);
            debugPrint('タグ更新: ${widget.video.tags}');
          }

          // 関連動画を取得（キャッシュがあれば使用）
          List<YoutubeVideo> relatedVideos;
          if (_relatedVideosCache != null) {
            relatedVideos = _relatedVideosCache!;
          } else {
            // 初回のみデバッグログを有効化
            relatedVideos = VideoService.getRelatedVideos(
              widget.video,
              allVideos,
              limit: 5,
              enableDebugLogs: false, // デバッグログを無効化
            );
            // 関連動画をキャッシュに保存
            _relatedVideosCache = relatedVideos;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with play button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Thumbnail
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildThumbnail(widget.video),
                    ),

                    // Play button - アーカイブモードが有効な場合のみ表示
                    if (_showArchiveSection)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openYouTube,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(204), // 0.8->204
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Title and date
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onDoubleTap: _activateArchiveMode, // Hidden trigger
                        child: Text(
                          widget.video.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDateTime,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tags
                      if (widget.video.tags.isNotEmpty)
                        SizedBox(
                          height: 30,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.video.tags.length,
                            separatorBuilder:
                                (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withAlpha(
                                    51,
                                  ), // 0.2->51
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  '#${widget.video.tags[index]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.secondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // お気に入りメモ表示セクション
                      if (_isFavorite &&
                          _favoriteNote != null &&
                          _favoriteNote!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'お気に入りメモ',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: _editFavoriteNote,
                                    color: Colors.red[400],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _favoriteNote!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // 動画情報セクション
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '動画情報',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              context,
                              '再生回数',
                              '${NumberFormat.decimalPattern().format(widget.video.viewCount.toInt())} 回',
                              Icons.visibility,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              context,
                              '高評価数',
                              '${NumberFormat.decimalPattern().format(widget.video.likeCount.toInt())} 件',
                              Icons.thumb_up,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              context,
                              '動画時間',
                              widget.video.duration,
                              Icons.timer,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Description
                      Text(
                        '説明',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.video.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // YouTubeボタン - アーカイブモードが有効な場合のみ機能する
                          _buildActionButton(
                            context,
                            widget.video.videoUrl.contains('x.com')
                                ? 'X'
                                : 'YouTube',
                            widget.video.videoUrl.contains('x.com')
                                ? null // アイコンの代わりに画像を使用するためnull
                                : Icons.play_arrow,
                            _showArchiveSection ? Colors.red : Colors.grey,
                            _openYouTube,
                            customImage:
                                widget.video.videoUrl.contains('x.com')
                                    ? 'assets/images/icon/x.jpg'
                                    : null,
                          ),
                          _buildActionButton(
                            context,
                            _isFavorite ? 'お気に入り済み' : 'お気に入り',
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            Colors.pink,
                            _toggleFavorite,
                          ),
                          _buildActionButton(
                            context,
                            '共有',
                            Icons.share,
                            Colors.blue,
                            _shareVideo,
                          ),
                        ],
                      ),

                      // Related videos
                      if (relatedVideos.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '関連動画',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...relatedVideos.map(
                          (video) => _buildRelatedVideoItem(context, video),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build an action button
  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData? icon,
    Color color,
    VoidCallback onPressed, {
    String? customImage,
  }) {
    return Column(
      children: [
        customImage != null
            ? InkWell(
              onTap: onPressed,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(
                  customImage,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            )
            : Material(
              color: color.withAlpha(26), // 0.1->26
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
            ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Build a related video item
  Widget _buildRelatedVideoItem(BuildContext context, YoutubeVideo video) {
    return InkWell(
      onTap: () {
        // Navigate to the video detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(video: video),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 120,
              height: 67.5, // 16:9のアスペクト比に合わせて高さを調整 (120 * 9/16 = 67.5)
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildThumbnail(video, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.formatDate(video.publishedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

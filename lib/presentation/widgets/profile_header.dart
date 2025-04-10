import 'package:flutter/material.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';
import 'package:marle_stream_history/data/video_data_manager.dart';
import 'package:intl/intl.dart';

/// A header widget that displays the Vtuber's profile
class ProfileHeader extends StatefulWidget {
  /// Constructor
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  // ビデオデータ用のFuture
  late Future<List<dynamic>> _videosFuture;
  late Future<double> _totalViewCountFuture;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // ビデオデータ取得を開始
    _videosFuture = VideoDataManager.getVideos();
    _totalViewCountFuture = VideoDataManager.getTotalViewCount();

    // Start the animation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime(2023, 10, 11);
    final formattedStartDate = DateFormat('yyyy/MM/dd').format(startDate);

    return FutureBuilder<List<dynamic>?>(
      future: Future.wait([_videosFuture, _totalViewCountFuture]),
      builder: (context, snapshot) {
        // データ読み込み中はローディング表示
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // エラー時の表示
        if (snapshot.hasError) {
          return Center(child: Text('データの読み込みに失敗しました: ${snapshot.error}'));
        }

        // データ取得成功
        final data = snapshot.data;
        final videos = data?[0] as List<dynamic>? ?? [];
        final totalViewCount = data?[1] as double? ?? 0.0;
        final videoCount = videos.length;

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _offsetAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withAlpha(102), // 0.4->102
                    AppTheme.secondaryColor.withAlpha(51), // 0.2->51
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Profile image with animated gradient border
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51), // 0.2->51
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3), // Border width
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/icon/Marle_icon.jpg',
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // 画面サイズに基づいてフォントサイズを計算
                                // より柔軟にサイズ調整
                                double nameSize;
                                if (constraints.maxWidth < 180) {
                                  nameSize = 18.0;
                                } else if (constraints.maxWidth < 220) {
                                  nameSize = 20.0;
                                } else {
                                  nameSize = 24.0;
                                }
                                
                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'マール',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: nameSize,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '・',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: nameSize,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'アストレア',
                                        style: TextStyle(
                                          color: AppTheme.secondaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: nameSize,
                                        ),
                                      ),
                                    ],
                                  ),
                                  softWrap: true, // 必要に応じて折り返し許可
                                );
                              }
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withAlpha(
                                  51,
                                ), // 0.2->51
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Virtual Youtuber',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(179), // 0.7->179
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13), // 0.05->13
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'アストレア法国出身の21歳！歌とゲームが大好きです！また時々お絵描き配信もしています。よろしくお願いします！',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Colors.white.withAlpha(128), // 0.5->128
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(context, '配信数', videoCount.toString()),
                          _buildDivider(),
                          _buildStatItem(
                            context,
                            '総再生回数',
                            _formatViewCount(totalViewCount),
                          ),
                          _buildDivider(),
                          _buildStatItem(context, '活動開始日', formattedStartDate),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withAlpha(77), // 0.3->77
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 画面幅に基づいてフォントサイズを調整
        final labelSize = MediaQuery.of(context).size.width < 360 ? 10.0 : 12.0;
        final valueSize = MediaQuery.of(context).size.width < 360 ? 12.0 : 14.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  /// Format view count to a human-readable format
  String _formatViewCount(double count) {
    // 1万単位で割って計算
    final valueInTenThousands = count / 10000;
    // 小数点第1位まで表示
    return '${valueInTenThousands.toStringAsFixed(1)}万';
  }
}

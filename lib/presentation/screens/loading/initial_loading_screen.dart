import 'package:flutter/material.dart';

class InitialLoadingScreen extends StatefulWidget {
  final Future<void> initializationFuture;
  final String loadingText;

  const InitialLoadingScreen({
    super.key,
    required this.initializationFuture,
    required this.loadingText,
  });

  @override
  InitialLoadingScreenState createState() => InitialLoadingScreenState();
}

class InitialLoadingScreenState extends State<InitialLoadingScreen> {
  double _progress = 0;
  String _status = '初期化中...';

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    try {
      await _updateProgress(0.2, 'データベースを準備中...');
      await widget.initializationFuture;
      await _updateProgress(0.8, '配信データを展開中...');
      await _updateProgress(1.0, '準備完了!');
    } catch (e) {
      await _updateProgress(1.0, 'エラーが発生しました');
      debugPrint('Initialization error: $e');
    }
  }

  Future<void> _updateProgress(double progress, String status) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _status = status;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).secondaryHeaderColor,
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icon/Marle_icon.jpg',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              Text(
                'マールの配信データを準備中...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '初回起動時はデータの展開に時間がかかります\n少々お待ちください',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

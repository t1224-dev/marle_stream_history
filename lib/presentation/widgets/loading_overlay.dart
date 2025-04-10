import 'package:flutter/material.dart';

/// フルスクリーンのローディングオーバーレイウィジェット
class LoadingOverlay extends StatelessWidget {
  /// ローディング中に表示するメッセージ
  final String message;

  /// 背景の色
  final Color backgroundColor;

  /// インジケーターの色
  final Color indicatorColor;

  /// コンストラクタ
  const LoadingOverlay({
    super.key,
    this.message = 'Loading...',
    this.backgroundColor = Colors.black54,
    this.indicatorColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: indicatorColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

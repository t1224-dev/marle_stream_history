import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marle_stream_history/data/services/data_loader_service.dart';
import 'package:marle_stream_history/domain/models/calendar_event.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';
import 'package:marle_stream_history/presentation/screens/video_detail/video_detail_screen.dart';
import 'package:marle_stream_history/presentation/widgets/video_card.dart';
import 'package:table_calendar/table_calendar.dart';

/// カレンダー画面
class CalendarScreen extends StatefulWidget {
  /// コンストラクタ
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with RestorationMixin, AutomaticKeepAliveClientMixin {
  PageController? _pageController;
  final RestorableDateTime _restorableFocusedDay = RestorableDateTime(
    DateTime.now(),
  );
  final RestorableDateTime _restorableSelectedDay = RestorableDateTime(
    DateTime.now(),
  );
  final RestorableInt _restorableCalendarFormat = RestorableInt(
    CalendarFormat.month.index,
  );

  DateTime get _focusedDay => _restorableFocusedDay.value;
  DateTime get _selectedDay => _restorableSelectedDay.value;
  CalendarFormat get _calendarFormat =>
      CalendarFormat.values[_restorableCalendarFormat.value];

  // カレンダーデータ関連のプロパティ
  Map<DateTime, List<CalendarEvent>> _eventMap = {}; // イベントデータを直接保持
  List<CalendarEvent> _selectedDayEvents = []; // 選択日のイベントを直接保持
  bool _isLoading = true; // ローディング状態制御用
  String? _errorMessage; // エラーメッセージ用

  // カレンダーの上限・下限
  DateTime _firstDay = DateTime(2020, 1, 1); // 初期値
  DateTime _lastDay = DateTime.now().add(
    const Duration(days: 30),
  ); // 初期値 - 現在から一ヶ月先まで

  @override
  String get restorationId => 'calendar_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // Restorableプロパティの登録（必須）
    registerForRestoration(_restorableFocusedDay, 'focused_day');
    registerForRestoration(_restorableSelectedDay, 'selected_day');
    registerForRestoration(_restorableCalendarFormat, 'calendar_format');

    // 注意: _initAsyncOperations() を initState() で実行しているので、
    // ここで再度読み込み処理を行う必要はありません
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ja_JP', null);

    // 初期化処理を開始 - 全てデータが揃ってからUIを構築するため
    _initializeData();
  }

  /// 初期化処理 - UI表示前に必要なすべてのデータをロード
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 永続化されたデータをロード
      await _loadPersistedState();

      // 2. イベントデータをロード（日付範囲を定めるために必要）
      _eventMap = await DataLoaderService.groupVideosByDate();
      debugPrint('カレンダーイベントロード完了: ${_eventMap.length} 日分のイベント');

      // 3. イベントデータから日付範囲を計算
      await _updateCalendarDateRange();

      // 4. フォーカス日と選択日を範囲内に調整
      _adjustDatesToRange();

      // 5. ページコントローラを初期化
      int pageIndex = _calculateInitialPage(focusedDay: _focusedDay);
      _pageController = PageController(initialPage: pageIndex, keepPage: true);

      // 6. 選択日のイベントを取得
      _updateSelectedDayEvents();

      // 7. ロード完了
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint(
        '初期化完了: フォーカス日=$_focusedDay, 選択日=$_selectedDay, 範囲=$_firstDay〜$_lastDay',
      );
    } catch (e) {
      debugPrint('初期化エラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'データの読み込みに失敗しました: $e';
        });
      }
    }
  }

  /// カレンダーの日付範囲を動画の投稿日時に基づいて設定
  Future<void> _updateCalendarDateRange() async {
    try {
      // イベントマップが空の場合、動画を直接ロードして確認
      if (_eventMap.isEmpty) {
        final videos = await DataLoaderService.loadVideos();
        if (videos.isEmpty) {
          // 動画がない場合はデフォルト範囲を設定
          final now = DateTime.now();
          _firstDay = DateTime(now.year - 1, now.month, 1);
          _lastDay = DateTime(now.year + 1, now.month + 1, 0);
          debugPrint('動画が見つからないため、デフォルト範囲を設定: $_firstDay 〜 $_lastDay');
          return;
        }

        // 日付でソート (昇順)
        videos.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

        // 最古と最新の動画日付を取得 (日本時間に変換)
        final earliestDate = videos.first.publishedAt.toLocal();
        final latestDate = videos.last.publishedAt.toLocal();

        // 月初と月末の計算（日本時間ベース）
        _firstDay = DateTime(earliestDate.year, earliestDate.month, 1);
        _lastDay = DateTime(
          latestDate.year,
          latestDate.month + 1,
          0,
        ); // 最後の月の末日
      } else {
        // イベントマップから日付範囲を計算
        final dates = _eventMap.keys.toList();
        dates.sort((a, b) => a.compareTo(b)); // 昇順ソート

        if (dates.isNotEmpty) {
          final earliestDate = dates.first;
          final latestDate = dates.last;

          // 月初と月末の計算
          _firstDay = DateTime(earliestDate.year, earliestDate.month, 1);
          _lastDay = DateTime(
            latestDate.year,
            latestDate.month + 1,
            0,
          ); // 最後の月の末日
        } else {
          // イベントがない場合はデフォルト範囲
          final now = DateTime.now();
          _firstDay = DateTime(now.year - 1, now.month, 1);
          _lastDay = DateTime(now.year + 1, now.month + 1, 0);
        }
      }

      debugPrint('カレンダー範囲を設定しました: $_firstDay 〜 $_lastDay');
    } catch (e) {
      // エラー時はデフォルトの日付範囲を設定
      debugPrint('日付範囲の設定に失敗しました: $e');
      final now = DateTime.now();
      _firstDay = DateTime(now.year - 1, 1, 1);
      _lastDay = DateTime(now.year + 1, 12, 31);
    }
  }

  /// フォーカス日と選択日を範囲内に調整
  void _adjustDatesToRange() {
    DateTime adjustedFocusedDay = _focusedDay;
    DateTime adjustedSelectedDay = _selectedDay;

    // フォーカス日の調整
    if (_focusedDay.isBefore(_firstDay)) {
      adjustedFocusedDay = _firstDay;
    } else if (_focusedDay.isAfter(_lastDay)) {
      adjustedFocusedDay = _lastDay;
    }

    // 選択日の調整
    if (_selectedDay.isBefore(_firstDay)) {
      adjustedSelectedDay = _firstDay;
    } else if (_selectedDay.isAfter(_lastDay)) {
      adjustedSelectedDay = _lastDay;
    }

    // 変更があれば更新
    if (adjustedFocusedDay != _focusedDay ||
        adjustedSelectedDay != _selectedDay) {
      setState(() {
        _restorableFocusedDay.value = adjustedFocusedDay;
        _restorableSelectedDay.value = adjustedSelectedDay;
      });
    }
  }

  /// 選択日のイベントを更新
  void _updateSelectedDayEvents() {
    // 選択日を正規化（時刻情報なし）
    final normalizedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    // 全てのキーを確認して日付が一致するものを探す
    List<CalendarEvent> dayEvents = [];
    for (final key in _eventMap.keys) {
      if (key.year == normalizedDay.year &&
          key.month == normalizedDay.month &&
          key.day == normalizedDay.day) {
        dayEvents = _eventMap[key] ?? [];
        break;
      }
    }

    // 動画数をカウント
    int totalVideos = 0;
    for (final event in dayEvents) {
      totalVideos += event.videos.length;
    }

    debugPrint(
      '選択日 ${normalizedDay.year}/${normalizedDay.month}/${normalizedDay.day} のイベント: ${dayEvents.length}件, 動画数: $totalVideos件',
    );

    setState(() {
      _selectedDayEvents = dayEvents;
    });
  }

  Future<void> _loadEvents() async {
    // 初期状態を空に設定しないようにして、マーカー表示を維持

    try {
      // グループ化されたイベントを取得
      final events = await DataLoaderService.groupVideosByDate();
      debugPrint('イベントマップ取得成功: ${events.length}件の日付');

      // デバッグ用：いくつかの日付のイベントを表示
      int i = 0;
      for (final entry in events.entries) {
        final date = entry.key;
        final eventsForDay = entry.value;
        int videoCount = 0;
        for (final event in eventsForDay) {
          videoCount += event.videos.length;
        }
        debugPrint(
          '日付 ${date.year}/${date.month}/${date.day}: $videoCount件の動画',
        );
        if (++i >= 5) break; // 最初の5件だけ表示
      }

      // UIを更新
      if (mounted) {
        setState(() {
          _eventMap = events;
        });
      }

      // マーカーが正しく表示されるように、後続でもう一度リビルドをトリガー
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // 強制的にリビルドをトリガー
            debugPrint('マーカー表示のために2回目のリビルドをトリガー');
          });
        }
      });

      // 現在選択されている日付のイベントを更新
      await _loadSelectedDayEvents();
    } catch (e) {
      debugPrint('イベント読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (isSameDay(_selectedDay, selectedDay)) {
      // 同じ日をタップしても何もしない
      debugPrint('同じ日を選択: $selectedDay');
      return;
    }

    debugPrint('日付選択: $selectedDay (前: $_selectedDay)');

    setState(() {
      _restorableSelectedDay.value = selectedDay;
      _restorableFocusedDay.value = focusedDay;
    });
    _savePersistedState();

    // 選択日のイベントを必ず読み込む
    _loadSelectedDayEvents();

    // 別の月の日付を選択した場合は、その月のイベントも再読み込み
    if (focusedDay.month != selectedDay.month ||
        focusedDay.year != selectedDay.year) {
      debugPrint('月が変更されたため、イベントを再読み込みします');
      _loadEvents();
    }
  }

  Future<void> _loadSelectedDayEvents() async {
    // 選択日が変わったので初期状態にリセット
    setState(() {
      _selectedDayEvents = []; // 選択日のイベントをリセット
    });

    try {
      // 選択日を正規化 (時刻情報なし)
      final normalizedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
      );

      debugPrint('選択日のイベントを読み込み中: $normalizedDay');

      // データローダーサービスから直接特定の日のイベントを取得
      // groupVideosByDate() は内部で全イベントをキャッシュするので高速
      final events = await DataLoaderService.getEventsForDay(normalizedDay);

      int totalVideos = 0;
      for (final event in events) {
        totalVideos += event.videos.length;
      }

      debugPrint(
        '選択日 ${normalizedDay.year}/${normalizedDay.month}/${normalizedDay.day} - '
        'イベント: ${events.length}件, 動画数: $totalVideos件',
      );

      if (events.isEmpty) {
        debugPrint('選択日のイベントは見つかりませんでした');
      } else if (totalVideos == 0) {
        debugPrint('選択日のイベントはありますが、動画が含まれていません');
      }

      // マウントされていれば状態を更新
      if (mounted) {
        setState(() {
          _selectedDayEvents = events;
        });
      }
    } catch (e) {
      debugPrint('選択日のイベント読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _selectedDayEvents = []; // エラー時も空リストを設定
        });
      }
    }
  }

  /// Handle format changed (month/week/day)
  void _onFormatChanged(CalendarFormat format) {
    setState(() {
      _restorableCalendarFormat.value = format.index;
    });
    _savePersistedState();
  }

  Future<void> _savePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDay', _selectedDay.toIso8601String());
    await prefs.setString('focusedDay', _focusedDay.toIso8601String());
    await prefs.setInt('calendarFormat', _calendarFormat.index);
  }

  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSelectedDay = prefs.getString('selectedDay');
    final savedFocusedDay = prefs.getString('focusedDay');
    final savedFormatIndex = prefs.getInt('calendarFormat');

    setState(() {
      _restorableSelectedDay.value =
          savedSelectedDay != null
              ? DateTime.parse(savedSelectedDay)
              : DateTime.now();
      _restorableFocusedDay.value =
          savedFocusedDay != null
              ? DateTime.parse(savedFocusedDay)
              : DateTime.now();
      _restorableCalendarFormat.value =
          savedFormatIndex ?? CalendarFormat.month.index;
    });
  }

  /// Handle page change in calendar
  void _onPageChanged(DateTime focusedDay) {
    // 設定された範囲外に移動しようとした場合は制限する
    if (focusedDay.isBefore(_firstDay) || focusedDay.isAfter(_lastDay)) {
      debugPrint('範囲外の月を選択: $focusedDay, 範囲: $_firstDay 〜 $_lastDay');
      // 範囲外ならページをリセット（範囲内に強制的に戻す）
      if (_pageController != null) {
        final correctPage = _calculateInitialPage(focusedDay: _focusedDay);
        debugPrint('ページを修正: $correctPage');
        _pageController!.jumpToPage(correctPage);
      }
      return;
    }

    debugPrint('カレンダー月変更: ${focusedDay.year}年${focusedDay.month}月');

    setState(() {
      _restorableFocusedDay.value = focusedDay;

      // 月が変わった場合は、新しい月の1日を選択する
      if (_selectedDay.month != focusedDay.month ||
          _selectedDay.year != focusedDay.year) {
        // 選択月の1日に設定
        _restorableSelectedDay.value = DateTime(
          focusedDay.year,
          focusedDay.month,
          1,
        );
      }
    });

    // イベントを再ロードし、UIを更新する
    _loadEvents();
    _loadSelectedDayEvents();
  }

  /// Build event markers for calendar
  Widget _buildEventMarker(DateTime day, List<dynamic> events) {
    if (events.isEmpty) return const SizedBox.shrink();

    // 日付のイベント数を直接表示
    int totalVideos = 0;
    for (final event in events) {
      if (event is CalendarEvent) {
        totalVideos += event.videos.length;
      }
    }

    // デバッグ出力
    debugPrint(
      'マーカー表示: ${day.year}/${day.month}/${day.day} - 動画数: $totalVideos',
    );

    if (totalVideos == 0) return const SizedBox.shrink();

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(204),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$totalVideos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(77),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle video tap
  void _handleVideoTap(YoutubeVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoDetailScreen(video: video)),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return SizedBox(
      height: 150, // 高さを増やして空の状態を見やすく
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // 必要なスペースのみ使用
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'この日の配信はありません',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '他の日付を選択してみませんか？',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// 選択日の動画数表示ラベルを构築
  Widget _buildDayEventCountLabel(
    int? count, {
    bool isLoading = false,
    bool hasError = false,
  }) {
    Color backgroundColor;
    Color textColor;
    String label;

    if (isLoading) {
      backgroundColor = Colors.grey[200]!;
      textColor = Colors.grey[600]!;
      label = '読み込み中...';
    } else if (hasError) {
      backgroundColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
      label = 'エラー';
    } else if (count == null || count == 0) {
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
      label = '配信なし';
    } else {
      backgroundColor = Theme.of(
        context,
      ).primaryColor.withAlpha(51); // 0.2の代わりにalphaを使用
      textColor = Theme.of(context).primaryColor;
      label = '$count件の配信';
      debugPrint('動画数ラベルに$count件を表示');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveCurrentPage();
    _pageController?.dispose();
    super.dispose();
  }

  int _calculateInitialPage({required DateTime focusedDay}) {
    // 基準日（最初の月）からの月数を計算
    // 最初の月と同じ場合は0、1ヶ月後は1、という具合
    final firstMonthDate = DateTime(_firstDay.year, _firstDay.month, 1);
    final targetMonthDate = DateTime(focusedDay.year, focusedDay.month, 1);

    // 年の差 * 12 + 月の差
    final yearDiff = targetMonthDate.year - firstMonthDate.year;
    final monthDiff = targetMonthDate.month - firstMonthDate.month;
    final page = yearDiff * 12 + monthDiff;

    debugPrint(
      '[DEBUG] ページ計算: 基準月=$firstMonthDate, 目標月=$targetMonthDate, ページ=$page',
    );
    return page >= 0 ? page : 0; // 負のページインデックスを防止
  }

  Future<void> _saveCurrentPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_page', _pageController?.page?.round() ?? 0);
    } catch (e) {
      debugPrint('ページ状態の保存に失敗しました: $e');
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixinのために必要

    // ローディング中の場合
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('カレンダーを読み込み中...'),
            ],
          ),
        ),
      );
    }

    // エラーの場合
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'エラーが発生しました',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    // 通常のカレンダー画面
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Calendar Title
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'カレンダー',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<CalendarFormat>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: _onFormatChanged,
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: CalendarFormat.month,
                                        child: Text('月表示'),
                                      ),
                                      const PopupMenuItem(
                                        value: CalendarFormat.week,
                                        child: Text('週表示'),
                                      ),
                                      const PopupMenuItem(
                                        value: CalendarFormat.twoWeeks,
                                        child: Text('2週間表示'),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        ),

                        // カレンダーウィジェット
                        SizedBox(
                          // カレンダー表示形式に応じて高さを動的に調整
                          height: _calendarFormat == CalendarFormat.month 
                              ? MediaQuery.of(context).size.height * 0.38
                              : _calendarFormat == CalendarFormat.twoWeeks 
                                  ? MediaQuery.of(context).size.height * 0.26
                                  : MediaQuery.of(context).size.height * 0.18, // 週表示は最もコンパクト
                          child: TableCalendar(
                            // カレンダー表示範囲の厳格な制限
                            availableGestures:
                                AvailableGestures.horizontalSwipe,
                            pageAnimationDuration: const Duration(
                              milliseconds: 300,
                            ),
                            pageAnimationCurve: Curves.easeOut,
                            firstDay: _firstDay,
                            lastDay: _lastDay,
                            focusedDay: _focusedDay,
                            locale: 'ja_JP',
                            // 月表示の場合のみ6行の高さを強制
                            sixWeekMonthsEnforced: _calendarFormat == CalendarFormat.month,
                            availableCalendarFormats: const {
                              CalendarFormat.month: '月表示',
                              CalendarFormat.twoWeeks: '2週間表示',
                              CalendarFormat.week: '週表示',
                            },
                            // イベントローダー - 各日付のイベントを提供
                            eventLoader: (day) {
                              final normalizedDay = DateTime(
                                day.year,
                                day.month,
                                day.day,
                              );

                              for (final key in _eventMap.keys) {
                                if (key.year == normalizedDay.year &&
                                    key.month == normalizedDay.month &&
                                    key.day == normalizedDay.day) {
                                  return _eventMap[key] ?? [];
                                }
                              }
                              return [];
                            },
                            rangeSelectionMode: RangeSelectionMode.disabled,
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              formatButtonPadding: const EdgeInsets.all(10),
                              // 表示形式に応じてヘッダーのパディングを調整
                              headerPadding: EdgeInsets.symmetric(
                                vertical: _calendarFormat == CalendarFormat.month ? 4.0 : 8.0,
                              ),
                              // 表示形式に応じてヘッダーの装飾を調整
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withAlpha(
                                  _calendarFormat == CalendarFormat.month ? 13 : 26,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              // 表示形式に応じてタイトルのテキストスタイルを調整
                              titleTextStyle: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: _calendarFormat == CalendarFormat.month ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                              // 表示形式に応じて矢印アイコンのサイズを調整
                              leftChevronIcon: Icon(
                                Icons.chevron_left,
                                color: Theme.of(context).primaryColor,
                                size: _calendarFormat == CalendarFormat.month ? 24 : 28,
                              ),
                              rightChevronIcon: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).primaryColor,
                                size: _calendarFormat == CalendarFormat.month ? 24 : 28,
                              ),
                            ),
                            selectedDayPredicate:
                                (day) => isSameDay(_selectedDay, day),
                            calendarFormat: _calendarFormat,
                            // カレンダーを常に全て表示
                            shouldFillViewport: true,
                            // 表示形式に応じて行の高さを調整
                            rowHeight: _calendarFormat == CalendarFormat.month 
                                ? 48.0
                                : 56.0, // 週表示と2週表示では行の高さを大きくする
                            // 曜日の高さも調整
                            daysOfWeekHeight: _calendarFormat == CalendarFormat.month ? 16.0 : 24.0,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            onDaySelected: _onDaySelected,
                            onFormatChanged: _onFormatChanged,
                            onPageChanged: _onPageChanged,
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                if (events.isEmpty) return null;
                                return Positioned(
                                  right: 1,
                                  bottom: _calendarFormat == CalendarFormat.month ? 1 : 2,
                                  child: _buildEventMarker(date, events),
                                );
                              },
                              selectedBuilder: (context, date, focusedDay) {
                                return Container(
                                  height: double.infinity,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              todayBuilder: (context, date, focusedDay) {
                                return Container(
                                  height: double.infinity,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withAlpha(77),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              // 表示形式に応じて日付セルのビルダーを調整
                              defaultBuilder: (context, date, focusedDay) {
                                return Container(
                                  margin: const EdgeInsets.all(2),
                                  height: double.infinity,
                                  child: Center(
                                    child: Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              // Note: weekendBuilder, outsideBuilder, and outsideWeekendBuilder are not available
                              // in the current version of table_calendar
                              // We will use the appropriate styles in calendarStyle instead
                            ),
                            calendarStyle: CalendarStyle(
                              // カスタムビルダーのサポートとしてデフォルトスタイルも設定
                              defaultTextStyle: TextStyle(
                                fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              selectedTextStyle: TextStyle(
                                color: Colors.white,
                                fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                              todayTextStyle: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                              weekendTextStyle: TextStyle(
                                color: Colors.red,
                                fontSize: _calendarFormat == CalendarFormat.month ? 16 : 18,
                              ),
                              // 表示形式に応じてセルのパディングとマージンを調整
                              cellPadding: _calendarFormat == CalendarFormat.month 
                                  ? const EdgeInsets.all(6.0) 
                                  : const EdgeInsets.all(8.0),
                              cellMargin: _calendarFormat == CalendarFormat.month 
                                  ? const EdgeInsets.all(4.0)
                                  : const EdgeInsets.all(6.0),
                              // 他のスタイル設定はそのまま保持
                              markersMaxCount: 1,
                              isTodayHighlighted: true,
                              outsideDaysVisible: true,
                              // Weekend and holiday styles are now handled by the weekendBuilder
                              markerDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withAlpha(77),
                                shape: BoxShape.circle,
                              )
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              // 表示形式に応じて曜日の背景色を調整
                              decoration: BoxDecoration(
                                color: _calendarFormat != CalendarFormat.month 
                                    ? Theme.of(context).primaryColor.withAlpha(13)
                                    : Colors.transparent,
                              ),
                              // 表示形式に応じて曜日のフォントサイズを調整
                              weekendStyle: TextStyle(
                                color: Colors.red,
                                fontSize: _calendarFormat == CalendarFormat.month ? 12.0 : 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                              weekdayStyle: TextStyle(
                                color: Theme.of(context).primaryColor.withAlpha(179),
                                fontSize: _calendarFormat == CalendarFormat.month ? 12.0 : 14.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ), // daysOfWeekStyle の閉じ括弧
                          ), // TableCalendar の閉じ括弧
                        ), // SizedBox の閉じ括弧
                        // Selected day header
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withAlpha(51),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat.yMMMMd('ja').format(_selectedDay),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withAlpha(204),
                                ),
                              ),
                              const Spacer(),
                              // 選択日の動画数表示
                              _buildDayEventCountLabel(
                                _getSelectedDayVideoCount(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 選択日の動画リスト
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _selectedDayEvents.isEmpty
                              ? _buildEmptyState()
                              : _buildVideoList(_selectedDayEvents),
                      childCount: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 選択日の動画数を取得
  int _getSelectedDayVideoCount() {
    int count = 0;
    for (final event in _selectedDayEvents) {
      count += event.videos.length;
    }
    return count;
  }

  /// Build video list for selected day
  Widget _buildVideoList(List<CalendarEvent> events) {
    // 選択された日のイベントから全ての動画を収集
    final List<YoutubeVideo> allVideos = [];
    int videoCount = 0;

    for (final event in events) {
      videoCount += event.videos.length;
      allVideos.addAll(event.videos);
      debugPrint('イベントID: ${event.id} - 動画数: ${event.videos.length}');
      for (final video in event.videos) {
        debugPrint('動画ID: ${video.videoId} タイトル: ${video.title}');
      }
    }

    debugPrint('選択日の全動画数: $videoCount');

    if (allVideos.isEmpty) {
      return _buildEmptyState();
    }

    // 公開日時順にソート (古いものが先)
    allVideos.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));

    // 動画リストのデバッグ情報
    debugPrint('表示する動画数: ${allVideos.length}');
    for (int i = 0; i < (allVideos.length > 3 ? 3 : allVideos.length); i++) {
      debugPrint('動画${i + 1}: ${allVideos[i].title} (${allVideos[i].videoId})');
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const NeverScrollableScrollPhysics(), // リスト自体のスクロールを無効化
      itemCount: allVideos.length,
      itemBuilder: (context, index) {
        final video = allVideos[index];
        debugPrint('レンダリング中の動画: ${video.title} (${video.videoId})');
        // thumbnailPathをそのまま使用し、VideoCard内でハンドリングする
        // VideoCardではパスが空の場合はデフォルト表示を生成するように修正済み
        // VideoCard内でthumbnailPathの存在チェックをしているので、そのまま渡す
        final fixedVideo = video;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: VideoCard(
            video: fixedVideo,
            isHorizontal: true,
            onTap: () => _handleVideoTap(video),
          ),
        );
      },
    );
  }
}

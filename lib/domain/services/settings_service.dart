import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:marle_stream_history/domain/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application settings
class SettingsService extends ChangeNotifier {
  /// Current application settings
  AppSettings _settings = AppSettings.defaults;

  // キー名
  static const String _settingsKey = 'app_settings';

  /// Get current settings
  AppSettings get settings => _settings;

  /// Whether dark mode is enabled
  bool get isDarkMode => _settings.themeMode == ThemeMode.dark;

  /// Whether to show archive URLs
  bool get enableArchiveUrls => _settings.enableArchiveUrls;

  /// Current theme mode
  ThemeMode get themeMode => _settings.themeMode;

  /// Initialize settings
  Future<void> init() async {
    try {
      // SharedPreferencesから設定を読み込む
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        // 保存されている設定があれば読み込む
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(settingsMap);
        debugPrint('設定を読み込みました: $settingsJson');
      } else {
        // 保存されている設定がなければデフォルト設定を使用
        _settings = AppSettings.defaults;
        debugPrint('デフォルト設定を使用します');
      }
    } catch (e) {
      // エラーが発生した場合はデフォルト設定を使用
      debugPrint('設定の読み込みエラー: $e');
      _settings = AppSettings.defaults;
    }

    notifyListeners();
  }

  /// Toggle theme mode
  void toggleTheme() {
    final newMode =
        _settings.themeMode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;
    _settings = _settings.copyWith(themeMode: newMode);
    _saveSettings();
    notifyListeners();
  }

  /// Set the theme mode explicitly
  void setThemeMode(ThemeMode mode) {
    _settings = _settings.copyWith(themeMode: mode);
    _saveSettings();
    notifyListeners();
  }

  /// Toggle archive URL display (hidden feature)
  void toggleArchiveUrls() {
    _settings = _settings.copyWith(
      enableArchiveUrls: !_settings.enableArchiveUrls,
    );
    _saveSettings();
    notifyListeners();
  }

  /// Handle tap on version number (for hidden feature activation)
  bool handleVersionTap() {
    final newCount = _settings.archiveActivationTapCount + 1;

    // Secret feature activation requires 5 taps
    if (newCount >= 5) {
      _settings = _settings.copyWith(
        archiveActivationTapCount: 0,
        enableArchiveUrls: true,
      );
      _saveSettings();
      notifyListeners();
      return true;
    } else {
      _settings = _settings.copyWith(archiveActivationTapCount: newCount);
      _saveSettings();
      return false;
    }
  }

  /// Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      debugPrint('設定を保存しました: $settingsJson');
    } catch (e) {
      debugPrint('設定の保存エラー: $e');
    }
  }
}

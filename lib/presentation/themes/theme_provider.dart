import 'package:flutter/material.dart';
import 'package:marle_stream_history/domain/services/settings_service.dart';
import 'package:marle_stream_history/presentation/themes/app_theme.dart';
import 'package:provider/provider.dart';

/// Provider for managing theme changes
class ThemeProvider extends ChangeNotifier {
  /// Default theme is light
  ThemeMode _themeMode = ThemeMode.light;

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Check if dark mode is enabled
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggle between light and dark themes
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Set specific theme mode
  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }

  /// Get the proper theme data based on current mode
  ThemeData getTheme(BuildContext context) {
    return _themeMode == ThemeMode.dark
        ? AppTheme.darkTheme()
        : AppTheme.lightTheme();
  }
  
  /// Initialize theme based on settings
  void initFromSettings(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    setThemeMode(settingsService.themeMode);
    
    // Listen for changes in the settings service
    settingsService.addListener(() {
      setThemeMode(settingsService.themeMode);
    });
  }
}

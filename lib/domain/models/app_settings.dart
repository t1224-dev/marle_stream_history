import 'package:flutter/material.dart';

/// Model for application settings
class AppSettings {
  /// Theme mode (light, dark, or system)
  ThemeMode themeMode;
  
  /// Whether to show archive URLs (hidden feature)
  bool enableArchiveUrls;
  
  /// Last synchronization date
  DateTime? lastSyncDate;
  
  /// Custom theme color
  String? customThemeColor;
  
  /// Count for activating archive mode (hidden feature)
  int archiveActivationTapCount;
  
  /// Number of days before an event to show a reminder
  int reminderDays;
  
  /// Constructor
  AppSettings({
    this.themeMode = ThemeMode.system,
    this.enableArchiveUrls = false,
    this.lastSyncDate,
    this.customThemeColor,
    this.archiveActivationTapCount = 0,
    this.reminderDays = 7,
  });
  
  /// Create a copy with updated values
  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? enableArchiveUrls,
    DateTime? lastSyncDate,
    String? customThemeColor,
    int? archiveActivationTapCount,
    int? reminderDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      enableArchiveUrls: enableArchiveUrls ?? this.enableArchiveUrls,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      customThemeColor: customThemeColor ?? this.customThemeColor,
      archiveActivationTapCount: archiveActivationTapCount ?? this.archiveActivationTapCount,
      reminderDays: reminderDays ?? this.reminderDays,
    );
  }
  
  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] ?? ThemeMode.system.index],
      enableArchiveUrls: json['enableArchiveUrls'] ?? false,
      lastSyncDate: json['lastSyncDate'] != null 
          ? DateTime.parse(json['lastSyncDate']) 
          : null,
      customThemeColor: json['customThemeColor'],
      archiveActivationTapCount: json['archiveActivationTapCount'] ?? 0,
      reminderDays: json['reminderDays'] ?? 7,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'enableArchiveUrls': enableArchiveUrls,
      'lastSyncDate': lastSyncDate?.toIso8601String(),
      'customThemeColor': customThemeColor,
      'archiveActivationTapCount': archiveActivationTapCount,
      'reminderDays': reminderDays,
    };
  }
  
  /// Default settings
  static AppSettings get defaults => AppSettings();
}

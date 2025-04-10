import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marle_stream_history/domain/models/favorite.dart';
import 'package:marle_stream_history/domain/models/youtube_video.dart';

/// Service for managing favorites
class FavoriteService extends ChangeNotifier {
  /// Key used to store favorites in SharedPreferences
  static const String _favoritesKey = 'favorites';
  
  /// List of favorites
  List<Favorite> _favorites = [];
  
  /// Get all favorites
  List<Favorite> get favorites => _favorites;
  
  /// Initialize the favorites service
  Future<void> init() async {
    await _loadFavorites();
  }
  
  /// Load favorites from persistent storage
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey);
      
      if (favoritesJson != null) {
        _favorites = favoritesJson
            .map((json) => Favorite.fromJson(jsonDecode(json)))
            .toList();
        
        // Sort by most recently added
        _favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = [];
    }
    
    notifyListeners();
  }
  
  /// Save favorites to persistent storage
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _favorites
          .map((favorite) => jsonEncode(favorite.toJson()))
          .toList();
      
      await prefs.setStringList(_favoritesKey, favoritesJson);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }
  
  /// Add a video to favorites
  Future<void> addFavorite(YoutubeVideo video, {String customNote = ''}) async {
    // Check if already in favorites
    if (isFavorite(video.videoId)) {
      return;
    }
    
    // Update the video's isFavorite flag
    video.isFavorite = true;
    
    // Create a new favorite
    final favorite = Favorite(
      videoId: video.videoId,
      addedAt: DateTime.now(),
      customNote: customNote,
    );
    
    _favorites.add(favorite);
    await _saveFavorites();
    notifyListeners();
  }
  
  /// Remove a video from favorites
  Future<void> removeFavorite(String videoId) async {
    _favorites.removeWhere((favorite) => favorite.videoId == videoId);
    await _saveFavorites();
    notifyListeners();
  }
  
  /// Toggle favorite status for a video
  Future<void> toggleFavorite(YoutubeVideo video) async {
    if (isFavorite(video.videoId)) {
      video.isFavorite = false;
      await removeFavorite(video.videoId);
    } else {
      video.isFavorite = true;
      await addFavorite(video);
    }
  }
  
  /// Check if a video is in favorites
  bool isFavorite(String videoId) {
    return _favorites.any((favorite) => favorite.videoId == videoId);
  }
  
  /// Update custom note for a favorite
  Future<void> updateNote(String videoId, String customNote) async {
    final index = _favorites.indexWhere((favorite) => favorite.videoId == videoId);
    
    if (index >= 0) {
      _favorites[index].customNote = customNote;
      await _saveFavorites();
      notifyListeners();
    }
  }
  
  /// Get favorite by video ID
  Favorite? getFavorite(String videoId) {
    try {
      return _favorites.firstWhere((favorite) => favorite.videoId == videoId);
    } catch (e) {
      return null;
    }
  }
  
  /// Update the list of videos with favorite status
  List<YoutubeVideo> updateVideosWithFavoriteStatus(List<YoutubeVideo> videos) {
    return videos.map((video) {
      return video.copyWith(
        isFavorite: isFavorite(video.videoId),
      );
    }).toList();
  }
  
  /// Clear all favorites
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing application cache
class CacheService {
  /// Get cache directory size in bytes
  Future<int> getCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      return await _calculateDirectorySize(tempDir);
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Clear application cache
  Future<bool> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      await _deleteDirectoryContents(tempDir);
      
      // Also clear the cache in app's internal directory
      final appDir = await getApplicationDocumentsDirectory();
      final cachePath = '${appDir.path}/thumbnails';
      final cacheDir = Directory(cachePath);
      
      if (await cacheDir.exists()) {
        await _deleteDirectoryContents(cacheDir);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }
  
  /// Format cache size to human-readable string
  String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Calculate size of directory including all subdirectories
  Future<int> _calculateDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      final files = directory.listSync(recursive: true, followLinks: false);
      for (FileSystemEntity entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return totalSize;
  }
  
  /// Delete all contents of a directory without deleting the directory itself
  Future<void> _deleteDirectoryContents(Directory directory) async {
    try {
      final files = directory.listSync(recursive: false, followLinks: false);
      for (FileSystemEntity entity in files) {
        try {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        } catch (e) {
          debugPrint('Error deleting ${entity.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error deleting directory contents: $e');
    }
  }
}

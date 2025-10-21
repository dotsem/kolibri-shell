import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';

/// Service for managing favorite applications in the app launcher.
/// Favorite apps are stored by their desktop file ID (e.g., "firefox.desktop")
class FavoriteAppsService extends ChangeNotifier {
  FavoriteAppsService._internal();

  static final FavoriteAppsService _instance = FavoriteAppsService._internal();
  factory FavoriteAppsService() => _instance;

  Set<String> _favoriteAppIds = <String>{};

  /// Check if an app is favorited
  bool isFavorite(String appId) {
    return _favoriteAppIds.contains(appId);
  }

  /// Toggle the favorite state of an app
  Future<void> toggleAppFavorite(String appId) async {
    if (_favoriteAppIds.contains(appId)) {
      _favoriteAppIds.remove(appId);
    } else {
      _favoriteAppIds.add(appId);
    }
    await _saveConfig();
    notifyListeners();
  }

  /// Favorite an app
  Future<void> favoriteApp(String appId) async {
    if (!_favoriteAppIds.contains(appId)) {
      _favoriteAppIds.add(appId);
      await _saveConfig();
      notifyListeners();
    }
  }

  /// Unfavorite an app
  Future<void> unfavoriteApp(String appId) async {
    if (_favoriteAppIds.remove(appId)) {
      await _saveConfig();
      notifyListeners();
    }
  }

  /// Load favorite apps from config file
  Future<void> loadConfig() async {
    try {
      final file = File(favoriteAppsConfigPath);
      if (!await file.exists()) {
        _favoriteAppIds = <String>{};
        return;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final favoriteList = json['favoriteApps'] as List<dynamic>? ?? [];
      _favoriteAppIds = Set<String>.from(favoriteList);
    } catch (e) {
      print('Error loading favorite apps config: $e');
      _favoriteAppIds = <String>{};
    }
  }

  /// Save favorite apps to config file
  Future<void> _saveConfig() async {
    try {
      // Ensure config directory exists
      final dir = Directory(configDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(favoriteAppsConfigPath);
      final json = {'favoriteApps': _favoriteAppIds.toList()};

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('Error saving favorite apps config: $e');
    }
  }

  /// Get the count of favorite apps
  int get favoriteCount => _favoriteAppIds.length;
}

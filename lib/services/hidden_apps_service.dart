import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';

/// Service for managing hidden applications in the app launcher.
/// Hidden apps are stored by their desktop file ID (e.g., "firefox.desktop")
class HiddenAppsService extends ChangeNotifier {
  HiddenAppsService._internal();

  static final HiddenAppsService _instance = HiddenAppsService._internal();
  factory HiddenAppsService() => _instance;

  Set<String> _hiddenAppIds = <String>{};
  bool _showHiddenApps = false;

  /// Returns true if hidden apps should be shown
  bool get showHiddenApps => _showHiddenApps;

  /// Toggle whether to show hidden apps
  void toggleShowHidden() {
    _showHiddenApps = !_showHiddenApps;
    notifyListeners();
  }

  /// Check if an app is hidden
  bool isHidden(String appId) {
    return _hiddenAppIds.contains(appId);
  }

  /// Toggle the hidden state of an app
  Future<void> toggleAppHidden(String appId) async {
    if (_hiddenAppIds.contains(appId)) {
      _hiddenAppIds.remove(appId);
    } else {
      _hiddenAppIds.add(appId);
    }
    await _saveConfig();
    notifyListeners();
  }

  /// Hide an app
  Future<void> hideApp(String appId) async {
    if (!_hiddenAppIds.contains(appId)) {
      _hiddenAppIds.add(appId);
      await _saveConfig();
      notifyListeners();
    }
  }

  /// Unhide an app
  Future<void> unhideApp(String appId) async {
    if (_hiddenAppIds.remove(appId)) {
      await _saveConfig();
      notifyListeners();
    }
  }

  /// Load hidden apps from config file
  Future<void> loadConfig() async {
    try {
      final file = File(hiddenAppsConfigPath);
      if (!await file.exists()) {
        _hiddenAppIds = <String>{};
        return;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final hiddenList = json['hiddenApps'] as List<dynamic>? ?? [];
      _hiddenAppIds = Set<String>.from(hiddenList);
    } catch (e) {
      print('Error loading hidden apps config: $e');
      _hiddenAppIds = <String>{};
    }
  }

  /// Save hidden apps to config file
  Future<void> _saveConfig() async {
    try {
      // Ensure config directory exists
      final dir = Directory(configDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File(hiddenAppsConfigPath);
      final json = {'hiddenApps': _hiddenAppIds.toList()};

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('Error saving hidden apps config: $e');
    }
  }

  /// Get the count of hidden apps
  int get hiddenCount => _hiddenAppIds.length;
}

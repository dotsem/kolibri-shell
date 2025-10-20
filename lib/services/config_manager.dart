import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';
import 'package:path/path.dart' as path;

/// Centralized configuration manager that handles all app configs
/// Stores configuration in individual JSON files in ~/.config/hypr_flutter/
class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;
  ConfigManager._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, List<VoidCallback>> _listeners = {};

  /// Initialize config directory
  Future<void> initialize() async {
    final dir = Directory(configDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('Created config directory: $configDirectory');
    }
  }

  /// Load config from a specific file
  Future<Map<String, dynamic>> loadConfig(String configPath) async {
    try {
      final file = File(configPath);
      if (!await file.exists()) {
        debugPrint('Config file not found: $configPath, returning empty map');
        return {};
      }

      final contents = await file.readAsString();
      final data = json.decode(contents) as Map<String, dynamic>;
      _cache[configPath] = data;
      debugPrint('Loaded config from: $configPath');
      return data;
    } catch (e) {
      debugPrint('Error loading config from $configPath: $e');
      return {};
    }
  }

  /// Save config to a specific file
  Future<bool> saveConfig(String configPath, Map<String, dynamic> data) async {
    try {
      await initialize(); // Ensure directory exists
      final file = File(configPath);

      // Pretty print JSON for readability
      final encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      await file.writeAsString(jsonString);
      _cache[configPath] = data;

      // Notify listeners
      _notifyListeners(configPath);

      debugPrint('Saved config to: $configPath');
      return true;
    } catch (e) {
      debugPrint('Error saving config to $configPath: $e');
      return false;
    }
  }

  /// Get a value from a config file
  Future<T?> getValue<T>(String configPath, String key, {T? defaultValue}) async {
    Map<String, dynamic> config;

    if (_cache.containsKey(configPath)) {
      config = _cache[configPath];
    } else {
      config = await loadConfig(configPath);
    }

    return (config[key] as T?) ?? defaultValue;
  }

  /// Set a value in a config file
  Future<bool> setValue(String configPath, String key, dynamic value) async {
    Map<String, dynamic> config;

    if (_cache.containsKey(configPath)) {
      config = Map<String, dynamic>.from(_cache[configPath]);
    } else {
      config = await loadConfig(configPath);
    }

    config[key] = value;
    return await saveConfig(configPath, config);
  }

  /// Get entire config file
  Future<Map<String, dynamic>> getConfig(String configPath) async {
    if (_cache.containsKey(configPath)) {
      return Map<String, dynamic>.from(_cache[configPath]);
    }
    return await loadConfig(configPath);
  }

  /// Update multiple values at once
  Future<bool> updateConfig(String configPath, Map<String, dynamic> updates) async {
    final config = await getConfig(configPath);
    config.addAll(updates);
    return await saveConfig(configPath, config);
  }

  /// Delete a key from config
  Future<bool> deleteKey(String configPath, String key) async {
    final config = await getConfig(configPath);
    config.remove(key);
    return await saveConfig(configPath, config);
  }

  /// Clear entire config file
  Future<bool> clearConfig(String configPath) async {
    return await saveConfig(configPath, {});
  }

  /// Check if config file exists
  Future<bool> configExists(String configPath) async {
    final file = File(configPath);
    return await file.exists();
  }

  /// Add a listener for config changes
  void addListener(String configPath, VoidCallback listener) {
    if (!_listeners.containsKey(configPath)) {
      _listeners[configPath] = [];
    }
    _listeners[configPath]!.add(listener);
  }

  /// Remove a listener
  void removeListener(String configPath, VoidCallback listener) {
    _listeners[configPath]?.remove(listener);
  }

  /// Notify all listeners for a config file
  void _notifyListeners(String configPath) {
    if (_listeners.containsKey(configPath)) {
      for (final listener in _listeners[configPath]!) {
        listener();
      }
    }
  }

  /// Export all configs to a backup directory
  Future<bool> exportConfigs(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final configDir = Directory(configDirectory);
      if (!await configDir.exists()) {
        return false;
      }

      final files = await configDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final fileName = path.basename(file.path);
          final destPath = path.join(backupPath, fileName);
          await file.copy(destPath);
        }
      }

      debugPrint('Exported configs to: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Error exporting configs: $e');
      return false;
    }
  }

  /// Import configs from a backup directory
  Future<bool> importConfigs(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        return false;
      }

      await initialize();

      final files = await backupDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final fileName = path.basename(file.path);
          final destPath = path.join(configDirectory, fileName);
          await file.copy(destPath);
        }
      }

      // Clear cache to force reload
      _cache.clear();

      debugPrint('Imported configs from: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Error importing configs: $e');
      return false;
    }
  }
}

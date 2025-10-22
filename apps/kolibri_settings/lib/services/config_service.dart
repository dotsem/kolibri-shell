import 'dart:io';
import 'dart:convert';
import '../config/config.dart';

/// Service for reading and writing JSON configuration files
class ConfigService {
  ConfigService._();
  static final ConfigService instance = ConfigService._();

  /// Read a JSON config file
  Future<Map<String, dynamic>?> readConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      final contents = await file.readAsString();
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading config from $filePath: $e');
      return null;
    }
  }

  /// Write a JSON config file
  Future<bool> writeConfig(String filePath, Map<String, dynamic> data) async {
    try {
      await ensureConfigDirectory();
      final file = File(filePath);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(jsonString);
      return true;
    } catch (e) {
      print('Error writing config to $filePath: $e');
      return false;
    }
  }

  /// Read appearance config
  Future<Map<String, dynamic>?> readAppearanceConfig() async {
    return readConfig(appearanceConfigPath);
  }

  /// Write appearance config
  Future<bool> writeAppearanceConfig(Map<String, dynamic> data) async {
    return writeConfig(appearanceConfigPath, data);
  }

  /// Read display config
  Future<Map<String, dynamic>?> readDisplayConfig() async {
    return readConfig(displayConfigPath);
  }

  /// Write display config
  Future<bool> writeDisplayConfig(Map<String, dynamic> data) async {
    return writeConfig(displayConfigPath, data);
  }

  /// Read general config
  Future<Map<String, dynamic>?> readGeneralConfig() async {
    return readConfig(generalConfigPath);
  }

  /// Write general config
  Future<bool> writeGeneralConfig(Map<String, dynamic> data) async {
    return writeConfig(generalConfigPath, data);
  }

  /// Check if a config file exists
  Future<bool> configExists(String filePath) async {
    return File(filePath).exists();
  }

  /// Delete a config file
  Future<bool> deleteConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('Error deleting config $filePath: $e');
      return false;
    }
  }
}

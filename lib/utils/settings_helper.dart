import 'package:hypr_flutter/services/settings.dart';

class SettingsHelper {
  static final SettingsService _settings = SettingsService();
  
  static Future<T> get<T>(SettingKey<T> key, [T? defaultValue]) async {
    await _settings.initialize();
    
    if (T == bool) {
      return await _settings.getBool(key as SettingKey<bool>) as T;
    } else if (T == String) {
      return await _settings.getString(key as SettingKey<String>) as T;
    } else if (T == int) {
      return await _settings.getInt(key as SettingKey<int>) as T;
    } else if (T == double) {
      return await _settings.getDouble(key as SettingKey<double>) as T;
    } else if (T == List<String>) {
      return await _settings.getStringList(key as SettingKey<List<String>>) as T;
    } else {
      return defaultValue ?? (key.defaultValue as T);
    }
  }
  
  static Future<void> set<T>(SettingKey<T> key, T value) async {
    await _settings.initialize();
    
    if (T == bool) {
      await _settings.setBool(key as SettingKey<bool>, value as bool);
    } else if (T == String) {
      await _settings.setString(key as SettingKey<String>, value as String);
    } else if (T == int) {
      await _settings.setInt(key as SettingKey<int>, value as int);
    } else if (T == double) {
      await _settings.setDouble(key as SettingKey<double>, value as double);
    } else if (T == List<String>) {
      await _settings.setStringList(key as SettingKey<List<String>>, value as List<String>);
    }
  }
}

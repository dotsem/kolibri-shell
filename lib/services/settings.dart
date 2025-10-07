import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class SettingKey<T> {
  const SettingKey(this.name, {this.defaultValue});

  final String name;
  final T? defaultValue;
}

class SettingsKeys {
  const SettingsKeys._();

  static const SettingKey<List<String>> visibleDisks = SettingKey<List<String>>(
    'system.visible_disks',
    defaultValue: <String>[],
  );

  static const SettingKey<bool> expandCpuSection = SettingKey<bool>(
    'system.cpu.expand',
    defaultValue: false,
  );

  static const List<SettingKey<dynamic>> all = <SettingKey<dynamic>>[
    visibleDisks,
    expandCpuSection,
  ];
}

class SettingsService {
  SettingsService._internal();

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;

  SharedPreferences? _prefs;
  Completer<void>? _initializationCompleter;

  Future<void> initialize() {
    if (_prefs != null) {
      return Future.value();
    }

    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _initializationCompleter = Completer<void>();

    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      _initializationCompleter?.complete();
      _initializationCompleter = null;
    }).catchError((error, stackTrace) {
      _initializationCompleter?.completeError(error, stackTrace);
      _initializationCompleter = null;
    });

    return _initializationCompleter!.future;
  }

  Future<bool> getBool(SettingKey<bool> key) async {
    await initialize();
    return _prefs?.getBool(key.name) ?? key.defaultValue ?? false;
  }

  Future<void> setBool(SettingKey<bool> key, bool value) async {
    await initialize();
    await _prefs?.setBool(key.name, value);
  }

  Future<String> getString(SettingKey<String> key) async {
    await initialize();
    return _prefs?.getString(key.name) ?? key.defaultValue ?? '';
  }

  Future<void> setString(SettingKey<String> key, String value) async {
    await initialize();
    await _prefs?.setString(key.name, value);
  }

  Future<List<String>> getStringList(SettingKey<List<String>> key) async {
    await initialize();
    return _prefs?.getStringList(key.name) ?? key.defaultValue ?? <String>[];
  }

  Future<void> setStringList(SettingKey<List<String>> key, List<String> values) async {
    await initialize();
    await _prefs?.setStringList(key.name, values);
  }

  Future<double> getDouble(SettingKey<double> key) async {
    await initialize();
    return _prefs?.getDouble(key.name) ?? key.defaultValue ?? 0;
  }

  Future<void> setDouble(SettingKey<double> key, double value) async {
    await initialize();
    await _prefs?.setDouble(key.name, value);
  }

  Future<int> getInt(SettingKey<int> key) async {
    await initialize();
    return _prefs?.getInt(key.name) ?? key.defaultValue ?? 0;
  }

  Future<void> setInt(SettingKey<int> key, int value) async {
    await initialize();
    await _prefs?.setInt(key.name, value);
  }

  Future<bool> contains(SettingKey<dynamic> key) async {
    await initialize();
    return _prefs?.containsKey(key.name) ?? false;
  }

  Future<void> remove(SettingKey<dynamic> key) async {
    await initialize();
    await _prefs?.remove(key.name);
  }
}

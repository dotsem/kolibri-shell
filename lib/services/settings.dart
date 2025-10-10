import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SettingKey<T> {
  const SettingKey(this.name, {this.defaultValue});

  final String name;
  final T? defaultValue;
}

class SettingsKeys {
  const SettingsKeys._();

  static const SettingKey<List<String>> visibleDisks = SettingKey<List<String>>('system.visible_disks', defaultValue: <String>[]);

  static const SettingKey<bool> expandCpuSection = SettingKey<bool>('system.cpu.expand', defaultValue: false);

  static const SettingKey<String> codeEditors = SettingKey<String>('code_editor.available', defaultValue: '{"vscode": "code", "windsurf": "windsurf"}');
  static const SettingKey<String> preferredCodeEditor = SettingKey<String>('code_editor.preferred', defaultValue: "windsurf");

  static const SettingKey<bool> darkModeEnabled = SettingKey<bool>('appearance.dark_mode', defaultValue: true);

  static const SettingKey<bool> enableBlur = SettingKey<bool>('appearance.enable_blur', defaultValue: true);
  static const SettingKey<int> primaryColor = SettingKey<int>('appearance.primary_color', defaultValue: 0xFF1E88E5);
  static const SettingKey<int> accentColor = SettingKey<int>('appearance.accent_color', defaultValue: 0xFFFFB300);
  static const SettingKey<int> backgroundColor = SettingKey<int>('appearance.background_color', defaultValue: 0xFF121212);
  static const SettingKey<int> containerColor = SettingKey<int>('appearance.container_color', defaultValue: 0xFF1F1F1F);
  static const SettingKey<double> taskbarOpacity = SettingKey<double>('taskbar.opacity', defaultValue: 0.9);
  static const SettingKey<bool> showSecondsOnClock = SettingKey<bool>('taskbar.clock.show_seconds', defaultValue: false);
  static const SettingKey<String> navbarPosition = SettingKey<String>('layout.navbar_position', defaultValue: 'top');
  static const SettingKey<String> monitorConfiguration = SettingKey<String>('display.monitor_configuration', defaultValue: '[]');

  static const List<SettingKey<dynamic>> all = <SettingKey<dynamic>>[
    visibleDisks,
    expandCpuSection,
    codeEditors,
    preferredCodeEditor,
    darkModeEnabled,
    enableBlur,
    primaryColor,
    accentColor,
    backgroundColor,
    containerColor,
    taskbarOpacity,
    showSecondsOnClock,
    navbarPosition,
    monitorConfiguration,
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

    SharedPreferences.getInstance()
        .then((prefs) {
          _prefs = prefs;
          _initializationCompleter?.complete();
          _initializationCompleter = null;
        })
        .catchError((error, stackTrace) {
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

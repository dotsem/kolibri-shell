import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ctl_models.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/windows/settings/settings_models.dart';

class SettingsApplyResult {
  const SettingsApplyResult({required this.requiresReload, required this.requiresRestart});

  final bool requiresReload;
  final bool requiresRestart;
}

class _SettingsSnapshot {
  _SettingsSnapshot({
    required this.darkModeEnabled,
    required this.enableBlur,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.containerColor,
    required this.taskbarOpacity,
    required this.showSecondsOnClock,
    required this.navbarPosition,
    required List<MonitorConfig> monitorConfigs,
  }) : monitorConfigs = List<MonitorConfig>.unmodifiable(monitorConfigs);

  final bool darkModeEnabled;
  final bool enableBlur;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color containerColor;
  final double taskbarOpacity;
  final bool showSecondsOnClock;
  final NavbarPosition navbarPosition;
  final List<MonitorConfig> monitorConfigs;

  _SettingsSnapshot copyWith({
    bool? darkModeEnabled,
    bool? enableBlur,
    Color? primaryColor,
    Color? accentColor,
    Color? backgroundColor,
    Color? containerColor,
    double? taskbarOpacity,
    bool? showSecondsOnClock,
    NavbarPosition? navbarPosition,
    List<MonitorConfig>? monitorConfigs,
  }) {
    return _SettingsSnapshot(
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      enableBlur: enableBlur ?? this.enableBlur,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      containerColor: containerColor ?? this.containerColor,
      taskbarOpacity: taskbarOpacity ?? this.taskbarOpacity,
      showSecondsOnClock: showSecondsOnClock ?? this.showSecondsOnClock,
      navbarPosition: navbarPosition ?? this.navbarPosition,
      monitorConfigs: monitorConfigs ?? this.monitorConfigs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _SettingsSnapshot) return false;
    return other.darkModeEnabled == darkModeEnabled &&
        other.enableBlur == enableBlur &&
        other.primaryColor == primaryColor &&
        other.accentColor == accentColor &&
        other.backgroundColor == backgroundColor &&
        other.containerColor == containerColor &&
        other.taskbarOpacity == taskbarOpacity &&
        other.showSecondsOnClock == showSecondsOnClock &&
        other.navbarPosition == navbarPosition &&
        _listEquals(other.monitorConfigs, monitorConfigs);
  }

  @override
  int get hashCode => Object.hash(
        darkModeEnabled,
        enableBlur,
        primaryColor,
        accentColor,
        backgroundColor,
        containerColor,
        taskbarOpacity,
        showSecondsOnClock,
        navbarPosition,
        Object.hashAll(monitorConfigs),
      );

  static bool _listEquals(List<MonitorConfig> a, List<MonitorConfig> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController();

  final SettingsService _settings = SettingsService();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  _SettingsSnapshot? _initial;
  _SettingsSnapshot? _draft;

  bool _requiresReload = false;
  bool _requiresRestart = false;

  bool get requiresReload => _requiresReload;
  bool get requiresRestart => _requiresRestart;
  bool get isDirty => _initial != _draft;

  bool get darkModeEnabled => _draft?.darkModeEnabled ?? true;
  bool get enableBlur => _draft?.enableBlur ?? true;
  Color get primaryColor => _draft?.primaryColor ?? Colors.blue;
  Color get accentColor => _draft?.accentColor ?? Colors.orange;
  Color get backgroundColor => _draft?.backgroundColor ?? const Color(0xFF121212);
  Color get containerColor => _draft?.containerColor ?? const Color(0xFF1F1F1F);
  double get taskbarOpacity => _draft?.taskbarOpacity ?? 0.9;
  bool get showSecondsOnClock => _draft?.showSecondsOnClock ?? false;
  NavbarPosition get navbarPosition => _draft?.navbarPosition ?? NavbarPosition.top;
  List<MonitorConfig> get monitorConfigs => List<MonitorConfig>.unmodifiable(_draft?.monitorConfigs ?? const <MonitorConfig>[]);

  bool get areMonitorsDuplicated {
    if (monitorConfigs.length <= 1) {
      return false;
    }
    final String primary = monitorConfigs.first.name;
    return monitorConfigs.skip(1).every((config) => config.isMirror && config.mirrorSource == primary);
  }

  ThemeData get themeData {
    final Brightness brightness = darkModeEnabled ? Brightness.dark : Brightness.light;
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: primaryColor, brightness: brightness).copyWith(
      primary: primaryColor,
      secondary: accentColor,
      surface: containerColor,
      surfaceTint: Colors.transparent,
      background: backgroundColor,
      onSurface: _contrastingColor(containerColor),
      onSurfaceVariant: _contrastingColor(containerColor).withOpacity(0.7),
      onBackground: _contrastingColor(backgroundColor),
      onPrimary: _contrastingColor(primaryColor),
      onSecondary: _contrastingColor(accentColor),
    );

    final TextTheme baseText = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: containerColor,
      textTheme: baseText.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: containerColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: baseText.titleLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: containerColor.withOpacity(brightness == Brightness.dark ? 0.65 : 0.9),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: _contrastingColor(scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurfaceVariant.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurface,
        subtitleTextStyle: TextStyle(color: scheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withOpacity(0.2),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withOpacity(0.12),
        valueIndicatorColor: scheme.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? scheme.primary : scheme.onSurfaceVariant.withOpacity(0.3)),
        checkColor: MaterialStateProperty.all<Color>(_contrastingColor(scheme.primary)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
        trackColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? scheme.primary.withOpacity(0.45) : scheme.onSurface.withOpacity(0.12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.onSurfaceVariant.withOpacity(0.2)),
    );
  }

  Future<void> load() async {
    await _settings.initialize();

    final bool darkMode = await _settings.getBool(SettingsKeys.darkModeEnabled);
    final bool blurEnabled = await _settings.getBool(SettingsKeys.enableBlur);
    final Color primary = Color(await _settings.getInt(SettingsKeys.primaryColor));
    final Color accent = Color(await _settings.getInt(SettingsKeys.accentColor));
    final Color background = Color(await _settings.getInt(SettingsKeys.backgroundColor));
    final Color container = Color(await _settings.getInt(SettingsKeys.containerColor));
    final double opacity = await _settings.getDouble(SettingsKeys.taskbarOpacity);
    final bool showSeconds = await _settings.getBool(SettingsKeys.showSecondsOnClock);
    final String navbarRaw = await _settings.getString(SettingsKeys.navbarPosition);

    List<MonitorConfig> monitors = await _loadLiveMonitorConfigs();
    final String storedMonitors = await _settings.getString(SettingsKeys.monitorConfiguration);
    if (monitors.isEmpty && storedMonitors.trim().isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(storedMonitors) as List<dynamic>;
        monitors = jsonList
            .map((dynamic item) => MonitorConfig.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (error) {
        debugPrint('SettingsController: failed to decode cached monitors: $error');
      }
    }

    _initial = _SettingsSnapshot(
      darkModeEnabled: darkMode,
      enableBlur: blurEnabled,
      primaryColor: primary,
      accentColor: accent,
      backgroundColor: background,
      containerColor: container,
      taskbarOpacity: opacity,
      showSecondsOnClock: showSeconds,
      navbarPosition: navbarPositionFromStorage(navbarRaw),
      monitorConfigs: monitors,
    );

    _draft = _initial;
    _isLoaded = true;
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    _updateDraft(_draft?.copyWith(darkModeEnabled: value), requiresReload: true);
  }

  void toggleBlur(bool value) {
    _updateDraft(_draft?.copyWith(enableBlur: value), requiresReload: true);
  }

  void updatePrimaryColor(Color color) {
    _updateDraft(_draft?.copyWith(primaryColor: color), requiresReload: true);
  }

  void updateAccentColor(Color color) {
    _updateDraft(_draft?.copyWith(accentColor: color), requiresReload: true);
  }

  void updateBackgroundColor(Color color) {
    _updateDraft(_draft?.copyWith(backgroundColor: color), requiresReload: true);
  }

  void updateContainerColor(Color color) {
    _updateDraft(_draft?.copyWith(containerColor: color), requiresReload: true);
  }

  void updateTaskbarOpacity(double value) {
    _updateDraft(_draft?.copyWith(taskbarOpacity: value.clamp(0.0, 1.0)), requiresReload: true);
  }

  void toggleShowSeconds(bool value) {
    _updateDraft(_draft?.copyWith(showSecondsOnClock: value), requiresReload: true);
  }

  void setNavbarPosition(NavbarPosition position) {
    _updateDraft(_draft?.copyWith(navbarPosition: position), requiresRestart: true);
  }

  void updateMonitorPosition(String name, int x, int y) {
    final List<MonitorConfig> updated = monitorConfigs
        .map((config) => config.name == name ? config.copyWith(x: x, y: y) : config)
        .toList();
    _updateDraft(_draft?.copyWith(monitorConfigs: updated), requiresRestart: true);
  }

  void updateMonitorScale(String name, double scale) {
    final double clamped = scale.clamp(0.5, 4.0);
    final List<MonitorConfig> updated = monitorConfigs
        .map((config) => config.name == name ? config.copyWith(scale: clamped) : config)
        .toList();
    _updateDraft(_draft?.copyWith(monitorConfigs: updated), requiresRestart: true);
  }

  void updateMonitorMirror(String name, {required bool isMirror, String? mirrorSource}) {
    final List<MonitorConfig> updated = monitorConfigs
        .map(
          (config) => config.name == name
              ? config.copyWith(isMirror: isMirror, mirrorSource: isMirror ? mirrorSource : null)
              : config,
        )
        .toList();
    _updateDraft(_draft?.copyWith(monitorConfigs: updated), requiresRestart: true);
  }

  void duplicateAllMonitors(bool duplicate) {
    if (monitorConfigs.isEmpty) return;
    final String primary = monitorConfigs.first.name;
    final List<MonitorConfig> updated = monitorConfigs.map((config) {
      if (!duplicate || config.name == primary) {
        return config.copyWith(isMirror: false, mirrorSource: null);
      }
      return config.copyWith(isMirror: true, mirrorSource: primary);
    }).toList();
    _updateDraft(_draft?.copyWith(monitorConfigs: updated), requiresRestart: true);
  }

  void discardChanges() {
    if (_initial == null) {
      return;
    }
    _draft = _initial;
    _requiresReload = false;
    _requiresRestart = false;
    notifyListeners();
  }

  Future<SettingsApplyResult> saveChanges() async {
    if (_draft == null) {
      return const SettingsApplyResult(requiresReload: false, requiresRestart: false);
    }

    final _SettingsSnapshot snapshot = _draft!;

    await _settings.setBool(SettingsKeys.darkModeEnabled, snapshot.darkModeEnabled);
    await _settings.setBool(SettingsKeys.enableBlur, snapshot.enableBlur);
    await _settings.setInt(SettingsKeys.primaryColor, snapshot.primaryColor.value);
    await _settings.setInt(SettingsKeys.accentColor, snapshot.accentColor.value);
    await _settings.setInt(SettingsKeys.backgroundColor, snapshot.backgroundColor.value);
    await _settings.setInt(SettingsKeys.containerColor, snapshot.containerColor.value);
    await _settings.setDouble(SettingsKeys.taskbarOpacity, snapshot.taskbarOpacity);
    await _settings.setBool(SettingsKeys.showSecondsOnClock, snapshot.showSecondsOnClock);
    await _settings.setString(SettingsKeys.navbarPosition, snapshot.navbarPosition.storageValue);
    await _settings.setString(
      SettingsKeys.monitorConfiguration,
      jsonEncode(snapshot.monitorConfigs.map((config) => config.toJson()).toList()),
    );

    final SettingsApplyResult result = SettingsApplyResult(
      requiresReload: _requiresReload,
      requiresRestart: _requiresRestart,
    );

    _initial = snapshot;
    _requiresReload = false;
    _requiresRestart = false;
    notifyListeners();
    return result;
  }

  Future<List<MonitorConfig>> _loadLiveMonitorConfigs() async {
    try {
      final List<Monitor> monitors = await hyprCtl.getMonitors();
      return monitors
          .map(
            (monitor) => MonitorConfig(
              name: monitor.name,
              description: monitor.desciprtion,
              width: monitor.width,
              height: monitor.height,
              refreshRate: monitor.refreshRate,
              x: monitor.x,
              y: monitor.y,
              scale: monitor.scale,
              isMirror: monitor.mirrorOf.isNotEmpty,
              mirrorSource: monitor.mirrorOf.isNotEmpty ? monitor.mirrorOf : null,
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('SettingsController: failed to load monitors via hyprctl: $error');
      return <MonitorConfig>[];
    }
  }

  void _updateDraft(_SettingsSnapshot? snapshot, {bool requiresReload = false, bool requiresRestart = false}) {
    if (snapshot == null) return;
    _draft = snapshot;
    if (requiresRestart) {
      _requiresRestart = true;
    }
    if (requiresReload && !_requiresRestart) {
      _requiresReload = true;
    }
    notifyListeners();
  }

  Color _contrastingColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
  }
}

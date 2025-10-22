import 'dart:convert';
import 'package:flutter/material.dart';

class AppearanceConfig {
  final bool darkMode;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color containerColor;
  final double taskbarOpacity;
  final bool enableBlur;
  final bool showSecondsOnClock;

  AppearanceConfig({
    this.darkMode = true,
    this.primaryColor = const Color(0xFF1E88E5),
    this.accentColor = const Color(0xFFFFB300),
    this.backgroundColor = const Color(0xFF121212),
    this.containerColor = const Color(0xFF1F1F1F),
    this.taskbarOpacity = 0.9,
    this.enableBlur = true,
    this.showSecondsOnClock = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'primaryColor': primaryColor.value,
      'accentColor': accentColor.value,
      'backgroundColor': backgroundColor.value,
      'containerColor': containerColor.value,
      'taskbarOpacity': taskbarOpacity,
      'enableBlur': enableBlur,
      'showSecondsOnClock': showSecondsOnClock,
    };
  }

  factory AppearanceConfig.fromJson(Map<String, dynamic> json) {
    return AppearanceConfig(
      darkMode: json['darkMode'] as bool? ?? true,
      primaryColor: Color(json['primaryColor'] as int? ?? 0xFF1E88E5),
      accentColor: Color(json['accentColor'] as int? ?? 0xFFFFB300),
      backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFF121212),
      containerColor: Color(json['containerColor'] as int? ?? 0xFF1F1F1F),
      taskbarOpacity: (json['taskbarOpacity'] as num?)?.toDouble() ?? 0.9,
      enableBlur: json['enableBlur'] as bool? ?? true,
      showSecondsOnClock: json['showSecondsOnClock'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppearanceConfig.fromJsonString(String jsonString) {
    return AppearanceConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  AppearanceConfig copyWith({bool? darkMode, Color? primaryColor, Color? accentColor, Color? backgroundColor, Color? containerColor, double? taskbarOpacity, bool? enableBlur, bool? showSecondsOnClock}) {
    return AppearanceConfig(
      darkMode: darkMode ?? this.darkMode,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      containerColor: containerColor ?? this.containerColor,
      taskbarOpacity: taskbarOpacity ?? this.taskbarOpacity,
      enableBlur: enableBlur ?? this.enableBlur,
      showSecondsOnClock: showSecondsOnClock ?? this.showSecondsOnClock,
    );
  }

  /// Generate a Flutter ThemeData from this config
  ThemeData toThemeData() {
    final brightness = darkMode ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(seedColor: primaryColor, brightness: brightness, primary: primaryColor, secondary: accentColor, background: backgroundColor, surface: containerColor);

    return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: colorScheme, scaffoldBackgroundColor: backgroundColor);
  }
}

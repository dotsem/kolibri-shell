import 'dart:convert';

import 'package:hypr_flutter/hyprland/ctl_models.dart';

class DisplayLayoutsBundle {
  const DisplayLayoutsBundle({required this.layouts, this.lastAppliedLayoutId});

  final List<DisplayLayout> layouts;
  final String? lastAppliedLayoutId;

  DisplayLayoutsBundle copyWith({List<DisplayLayout>? layouts, String? lastAppliedLayoutId}) {
    return DisplayLayoutsBundle(
      layouts: layouts ?? this.layouts,
      lastAppliedLayoutId: lastAppliedLayoutId ?? this.lastAppliedLayoutId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'layouts': layouts.map((layout) => layout.toJson()).toList(),
      'lastAppliedLayoutId': lastAppliedLayoutId,
    };
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory DisplayLayoutsBundle.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLayouts = json['layouts'] as List<dynamic>? ?? const <dynamic>[];
    return DisplayLayoutsBundle(
      layouts: rawLayouts
          .map((dynamic item) => DisplayLayout.fromJson(item as Map<String, dynamic>))
          .toList(),
      lastAppliedLayoutId: json['lastAppliedLayoutId'] as String?,
    );
  }

  static DisplayLayoutsBundle empty() => const DisplayLayoutsBundle(layouts: <DisplayLayout>[]);
}

class DisplayLayout {
  const DisplayLayout({
    required this.id,
    required this.label,
    required this.monitors,
    this.updatedAt,
  });

  final String id;
  final String label;
  final List<MonitorLayout> monitors;
  final DateTime? updatedAt;

  MonitorLayout? get primaryMonitor {
    if (monitors.isEmpty) {
      return null;
    }
    for (final monitor in monitors) {
      if (monitor.isPrimary) {
        return monitor;
      }
    }
    return monitors.first;
  }

  DisplayLayout copyWith({String? id, String? label, List<MonitorLayout>? monitors, DateTime? updatedAt}) {
    return DisplayLayout(
      id: id ?? this.id,
      label: label ?? this.label,
      monitors: monitors ?? this.monitors,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'updatedAt': updatedAt?.toIso8601String(),
      'monitors': monitors.map((monitor) => monitor.toJson()).toList(),
    };
  }

  factory DisplayLayout.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMonitors = json['monitors'] as List<dynamic>? ?? const <dynamic>[];
    return DisplayLayout(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      monitors: rawMonitors.map((dynamic item) => MonitorLayout.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class MonitorLayout {
  const MonitorLayout({
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.refreshRate,
    required this.x,
    required this.y,
    required this.scale,
    this.enabled = true,
    this.isPrimary = false,
    this.isMirror = false,
    this.mirrorSource,
  });

  static const Object _mirrorSourceSentinel = Object();

  final String name;
  final String description;
  final int width;
  final int height;
  final double refreshRate;
  final int x;
  final int y;
  final double scale;
  final bool enabled;
  final bool isPrimary;
  final bool isMirror;
  final String? mirrorSource;

  String get modeString {
    final bool hasFraction = refreshRate % 1 != 0;
    final String formattedRate = hasFraction ? refreshRate.toStringAsFixed(2) : refreshRate.toStringAsFixed(0);
    return '${width}x${height}@${formattedRate}';
  }

  MonitorLayout copyWith({
    int? width,
    int? height,
    double? refreshRate,
    int? x,
    int? y,
    double? scale,
    bool? enabled,
    bool? isPrimary,
    bool? isMirror,
    Object? mirrorSource = _mirrorSourceSentinel,
  }) {
    return MonitorLayout(
      name: name,
      description: description,
      width: width ?? this.width,
      height: height ?? this.height,
      refreshRate: refreshRate ?? this.refreshRate,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      enabled: enabled ?? this.enabled,
      isPrimary: isPrimary ?? this.isPrimary,
      isMirror: isMirror ?? this.isMirror,
      mirrorSource: identical(mirrorSource, _mirrorSourceSentinel) ? this.mirrorSource : mirrorSource as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'width': width,
      'height': height,
      'refreshRate': refreshRate,
      'x': x,
      'y': y,
      'scale': scale,
      'enabled': enabled,
      'isPrimary': isPrimary,
      'isMirror': isMirror,
      'mirrorSource': mirrorSource,
    };
  }

  factory MonitorLayout.fromJson(Map<String, dynamic> json) {
    return MonitorLayout(
      name: json['name'] as String,
      description: json['description'] as String? ?? json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      refreshRate: (json['refreshRate'] as num).toDouble(),
      x: json['x'] as int,
      y: json['y'] as int,
      scale: (json['scale'] as num).toDouble(),
      enabled: json['enabled'] as bool? ?? true,
      isPrimary: json['isPrimary'] as bool? ?? false,
      isMirror: json['isMirror'] as bool? ?? false,
      mirrorSource: json['mirrorSource'] as String?,
    );
  }

  factory MonitorLayout.fromMonitor(Monitor monitor, {bool isPrimary = false}) {
    return MonitorLayout(
      name: monitor.name,
      description: monitor.desciprtion,
      width: monitor.width,
      height: monitor.height,
      refreshRate: monitor.refreshRate,
      x: monitor.x,
      y: monitor.y,
      scale: monitor.scale,
      enabled: !monitor.disabled,
      isPrimary: isPrimary,
      isMirror: monitor.mirrorOf.isNotEmpty,
      mirrorSource: monitor.mirrorOf.isNotEmpty ? monitor.mirrorOf : null,
    );
  }
}

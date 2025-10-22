import 'dart:convert';

class MonitorConfig {
  final String name;
  final bool enabled;
  final Resolution resolution;
  final double refreshRate;
  final Position position;
  final double scale;
  final int rotation; // 0, 90, 180, 270
  final String? mirror; // Monitor name to mirror, or null
  final bool isPrimary;

  MonitorConfig({required this.name, this.enabled = true, required this.resolution, required this.refreshRate, required this.position, this.scale = 1.0, this.rotation = 0, this.mirror, this.isPrimary = false});

  Map<String, dynamic> toJson() {
    return {'name': name, 'enabled': enabled, 'resolution': resolution.toJson(), 'refreshRate': refreshRate, 'position': position.toJson(), 'scale': scale, 'rotation': rotation, 'mirror': mirror, 'isPrimary': isPrimary};
  }

  factory MonitorConfig.fromJson(Map<String, dynamic> json) {
    return MonitorConfig(
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      resolution: Resolution.fromJson(json['resolution'] as Map<String, dynamic>),
      refreshRate: (json['refreshRate'] as num).toDouble(),
      position: Position.fromJson(json['position'] as Map<String, dynamic>),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: json['rotation'] as int? ?? 0,
      mirror: json['mirror'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  MonitorConfig copyWith({String? name, bool? enabled, Resolution? resolution, double? refreshRate, Position? position, double? scale, int? rotation, String? Function()? mirror, bool? isPrimary}) {
    return MonitorConfig(
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      resolution: resolution ?? this.resolution,
      refreshRate: refreshRate ?? this.refreshRate,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      mirror: mirror != null ? mirror() : this.mirror,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class Resolution {
  final int width;
  final int height;

  Resolution(this.width, this.height);

  Map<String, dynamic> toJson() => {'width': width, 'height': height};

  factory Resolution.fromJson(Map<String, dynamic> json) {
    return Resolution(json['width'] as int, json['height'] as int);
  }

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) => identical(this, other) || other is Resolution && runtimeType == other.runtimeType && width == other.width && height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

class Position {
  final int x;
  final int y;

  Position(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(json['x'] as int, json['y'] as int);
  }

  @override
  String toString() => '$x,$y';
}

class DisplayConfig {
  final List<MonitorConfig> monitors;
  final DateTime lastModified;

  DisplayConfig({required this.monitors, DateTime? lastModified}) : lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {'monitors': monitors.map((m) => m.toJson()).toList(), 'lastModified': lastModified.toIso8601String()};
  }

  factory DisplayConfig.fromJson(Map<String, dynamic> json) {
    return DisplayConfig(monitors: (json['monitors'] as List).map((m) => MonitorConfig.fromJson(m as Map<String, dynamic>)).toList(), lastModified: DateTime.parse(json['lastModified'] as String));
  }

  String toJsonString() => jsonEncode(toJson());

  factory DisplayConfig.fromJsonString(String jsonString) {
    return DisplayConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Represents a physical monitor detected by Hyprland
class Monitor {
  final int id;
  final String name;
  final String description;
  final String make;
  final String model;
  final int width;
  final int height;
  final double refreshRate;
  final int x;
  final int y;
  final double scale;
  final int transform;
  final bool focused;
  final bool dpmsStatus;
  final bool vrr;
  final bool disabled;
  final String mirrorOf;
  final List<String> availableModes;

  Monitor({
    required this.id,
    required this.name,
    required this.description,
    required this.make,
    required this.model,
    required this.width,
    required this.height,
    required this.refreshRate,
    required this.x,
    required this.y,
    required this.scale,
    required this.transform,
    required this.focused,
    required this.dpmsStatus,
    required this.vrr,
    required this.disabled,
    required this.mirrorOf,
    required this.availableModes,
  });

  /// Parse monitor data from hyprctl JSON output
  factory Monitor.fromHyprctl(Map<String, dynamic> json) {
    return Monitor(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      width: json['width'] as int,
      height: json['height'] as int,
      refreshRate: (json['refreshRate'] as num).toDouble(),
      x: json['x'] as int,
      y: json['y'] as int,
      scale: (json['scale'] as num).toDouble(),
      transform: json['transform'] as int,
      focused: json['focused'] as bool? ?? false,
      dpmsStatus: json['dpmsStatus'] as bool? ?? true,
      vrr: json['vrr'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      mirrorOf: json['mirrorOf'] as String? ?? 'none',
      availableModes: (json['availableModes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// Convert to MonitorConfig for saving
  MonitorConfig toMonitorConfig({bool isPrimary = false}) {
    return MonitorConfig(
      name: name,
      enabled: !disabled,
      resolution: Resolution(width, height),
      refreshRate: refreshRate,
      position: Position(x, y),
      scale: scale,
      rotation: transform * 90, // transform 0-3 maps to 0-270
      mirror: mirrorOf != 'none' ? mirrorOf : null,
      isPrimary: isPrimary,
    );
  }

  /// Parse available modes into list of resolutions with refresh rates
  List<ResolutionMode> get parsedModes {
    final modes = <ResolutionMode>[];
    for (final mode in availableModes) {
      // Parse format like "1920x1080@60.01Hz"
      final match = RegExp(r'(\d+)x(\d+)@([\d.]+)Hz').firstMatch(mode);
      if (match != null) {
        modes.add(ResolutionMode(Resolution(int.parse(match.group(1)!), int.parse(match.group(2)!)), double.parse(match.group(3)!)));
      }
    }
    return modes;
  }

  /// Get unique resolutions from available modes
  List<Resolution> get availableResolutions {
    final resolutions = parsedModes.map((m) => m.resolution).toSet().toList();
    resolutions.sort((a, b) => (b.width * b.height) - (a.width * a.height));
    return resolutions;
  }

  /// Get available refresh rates for a specific resolution
  List<double> getRefreshRatesForResolution(Resolution resolution) {
    final rates =
        parsedModes
            .where((m) => m.resolution == resolution)
            .map((m) => m.refreshRate)
            .toSet() // Remove duplicates
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return rates;
  }
}

/// Represents a resolution with refresh rate
class ResolutionMode {
  final Resolution resolution;
  final double refreshRate;

  ResolutionMode(this.resolution, this.refreshRate);

  @override
  String toString() => '${resolution}@${refreshRate.toStringAsFixed(2)}Hz';
}

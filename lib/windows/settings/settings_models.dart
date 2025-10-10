enum NavbarPosition { top, bottom }

extension NavbarPositionX on NavbarPosition {
  String get label {
    switch (this) {
      case NavbarPosition.top:
        return 'Top';
      case NavbarPosition.bottom:
        return 'Bottom';
    }
  }

  String get storageValue {
    switch (this) {
      case NavbarPosition.top:
        return 'top';
      case NavbarPosition.bottom:
        return 'bottom';
    }
  }
}

NavbarPosition navbarPositionFromStorage(String value) {
  switch (value) {
    case 'bottom':
      return NavbarPosition.bottom;
    case 'top':
    default:
      return NavbarPosition.top;
  }
}

class MonitorConfig {
  const MonitorConfig({
    required this.name,
    required this.description,
    required this.width,
    required this.height,
    required this.refreshRate,
    required this.x,
    required this.y,
    required this.scale,
    this.isMirror = false,
    this.mirrorSource,
  });

  final String name;
  final String description;
  final int width;
  final int height;
  final double refreshRate;
  final int x;
  final int y;
  final double scale;
  final bool isMirror;
  final String? mirrorSource;

  MonitorConfig copyWith({
    int? x,
    int? y,
    double? scale,
    bool? isMirror,
    String? mirrorSource,
  }) {
    return MonitorConfig(
      name: name,
      description: description,
      width: width,
      height: height,
      refreshRate: refreshRate,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      isMirror: isMirror ?? this.isMirror,
      mirrorSource: mirrorSource ?? this.mirrorSource,
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
      'isMirror': isMirror,
      'mirrorSource': mirrorSource,
    };
  }

  factory MonitorConfig.fromJson(Map<String, dynamic> json) {
    return MonitorConfig(
      name: json['name'] as String,
      description: json['description'] as String? ?? json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      refreshRate: (json['refreshRate'] as num).toDouble(),
      x: json['x'] as int,
      y: json['y'] as int,
      scale: (json['scale'] as num).toDouble(),
      isMirror: json['isMirror'] as bool? ?? false,
      mirrorSource: json['mirrorSource'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MonitorConfig) return false;
    return name == other.name &&
        description == other.description &&
        width == other.width &&
        height == other.height &&
        refreshRate == other.refreshRate &&
        x == other.x &&
        y == other.y &&
        scale == other.scale &&
        isMirror == other.isMirror &&
        mirrorSource == other.mirrorSource;
  }

  @override
  int get hashCode => Object.hash(name, description, width, height, refreshRate, x, y, scale, isMirror, mirrorSource);
}

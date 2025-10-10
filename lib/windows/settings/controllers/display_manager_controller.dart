import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:hypr_flutter/models/display_layout.dart';
import 'package:hypr_flutter/services/display_manager.dart';

class DisplayManagerController extends ChangeNotifier {
  DisplayManagerController({DisplayManagerService? service}) : _service = service ?? DisplayManagerService();

  final DisplayManagerService _service;

  bool _initialized = false;
  bool _initializing = false;
  bool _applying = false;
  bool _saving = false;
  bool _dirty = false;

  List<MonitorLayout> _monitors = <MonitorLayout>[];
  MonitorLayout? _selected;
  List<DisplayLayout> _layouts = <DisplayLayout>[];
  String? _activeLayoutId;
  String? _pendingLayoutId;

  late final VoidCallback _serviceListener;

  bool get isInitialized => _initialized;
  bool get isLoading => _initializing;
  bool get isApplying => _applying;
  bool get isSaving => _saving;
  bool get hasPendingChanges => _dirty;

  List<MonitorLayout> get monitors => List<MonitorLayout>.unmodifiable(_monitors);
  MonitorLayout? get selectedMonitor => _selected;
  List<DisplayLayout> get layouts => List<DisplayLayout>.unmodifiable(_layouts);
  String? get activeLayoutId => _activeLayoutId;
  String? get pendingLayoutId => _pendingLayoutId;

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }

    _initializing = true;
    notifyListeners();

    _serviceListener = _handleServiceChanged;
    _service.addListener(_serviceListener);

    try {
      await _service.initialize();
      _syncFromService(resetSelection: true, includeLiveMonitors: true);
      _initialized = true;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshLiveMonitors() async {
    await _service.refreshMonitors();
    _syncFromService(includeLiveMonitors: !_dirty);
  }

  void selectMonitor(String name) {
    final MonitorLayout? monitor = _findMonitorByName(name);
    if (monitor == null || identical(monitor, _selected)) {
      return;
    }
    _selected = monitor;
    notifyListeners();
  }

  void setMonitorPosition(String name, int x, int y) {
    _modifyMonitor(name, (monitor) => monitor.copyWith(x: x, y: y));
  }

  void setMonitorScale(String name, double scale) {
    _modifyMonitor(name, (monitor) => monitor.copyWith(scale: scale.clamp(0.5, 4.0)));
  }

  void setMonitorEnabled(String name, bool enabled) {
    _modifyMonitor(name, (monitor) => monitor.copyWith(enabled: enabled));
  }

  void setPrimary(String name) {
    bool updated = false;
    _monitors = _monitors.map((monitor) {
      final bool isPrimary = monitor.name == name && monitor.enabled;
      if (monitor.isPrimary != isPrimary) {
        updated = true;
      }
      return monitor.copyWith(isPrimary: isPrimary);
    }).toList();

    if (updated) {
      _dirty = true;
      final MonitorLayout? refreshed = _findMonitorByName(name);
      _selected = refreshed ?? _selected;
      notifyListeners();
    }
  }

  void setMirror(String name, {required bool enabled, String? source}) {
    if (enabled && (source == null || source.isEmpty)) {
      return;
    }

    _modifyMonitor(
      name,
      (monitor) => monitor.copyWith(
        isMirror: enabled,
        mirrorSource: enabled ? source : null,
        enabled: enabled ? true : monitor.enabled,
      ),
    );
  }

  void setMirrorAll(bool enabled) {
    if (_monitors.isEmpty) {
      return;
    }

    final MonitorLayout? primary = _findPrimaryMonitor();
    if (enabled && primary == null) {
      return;
    }

    _monitors = _monitors.map((monitor) {
      if (primary != null && monitor.name == primary.name) {
        return monitor.copyWith(isMirror: false, mirrorSource: null);
      }
      if (!enabled) {
        return monitor.copyWith(isMirror: false, mirrorSource: null);
      }
      return monitor.copyWith(isMirror: true, mirrorSource: primary?.name);
    }).toList();

    _selected = _selected != null ? _findMonitorByName(_selected!.name) ?? _selected : null;
    _dirty = true;
    notifyListeners();
  }

  bool get isMirrorAllEnabled {
    if (_monitors.length <= 1) return false;
    final MonitorLayout? primary = _findPrimaryMonitor();
    if (primary == null) return false;
    for (final MonitorLayout monitor in _monitors) {
      if (monitor.name == primary.name) continue;
      if (!monitor.isMirror || monitor.mirrorSource != primary.name) {
        return false;
      }
    }
    return true;
  }

  Future<void> applyChanges() async {
    if (_applying) {
      return;
    }

    _applying = true;
    notifyListeners();

    try {
      await _service.applyLiveLayout(_monitors);
      _dirty = false;
      _pendingLayoutId = _service.lastAppliedLayout?.id ?? _pendingLayoutId;
      await _service.refreshMonitors();
      _syncFromService(includeLiveMonitors: true);
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  Future<void> applyLayout(String layoutId) async {
    _pendingLayoutId = layoutId;
    notifyListeners();
    await _service.applyLayoutById(layoutId);
    await _service.refreshMonitors();
    _dirty = false;
    _pendingLayoutId = null;
    _syncFromService(includeLiveMonitors: true);
  }

  Future<void> loadLayoutForEditing(String layoutId) async {
    final DisplayLayout? layout = _findLayoutById(layoutId);
    if (layout == null) {
      return;
    }

    _monitors = layout.monitors.map((monitor) => monitor.copyWith()).toList();
    _selected = _monitors.isNotEmpty ? _monitors.first : null;
    _activeLayoutId = layoutId;
    _dirty = true;
    notifyListeners();
  }

  Future<void> saveLayout(String id, String label) async {
    if (_saving) {
      return;
    }

    _saving = true;
    notifyListeners();

    try {
      final DisplayLayout layout = DisplayLayout(
        id: id,
        label: label,
        monitors: _monitors.map((monitor) => monitor.copyWith()).toList(),
        updatedAt: DateTime.now(),
      );
      await _service.saveLayout(layout, setAsLastApplied: false);
      _dirty = false;
      _activeLayoutId = id;
      _syncFromService(includeLiveMonitors: false);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> deleteLayout(String id) async {
    await _service.deleteLayout(id);
    _syncFromService(includeLiveMonitors: false);
  }

  void resetToLiveConfiguration() {
    _syncFromService(includeLiveMonitors: true);
    _dirty = false;
    notifyListeners();
  }

  Rect computeBoundingBox({double padding = 200}) {
    if (_monitors.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final MonitorLayout monitor in _monitors) {
      if (!monitor.enabled) continue;
      minX = min(minX, monitor.x.toDouble());
      minY = min(minY, monitor.y.toDouble());
      maxX = max(maxX, (monitor.x + monitor.width).toDouble());
      maxY = max(maxY, (monitor.y + monitor.height).toDouble());
    }

    if (minX == double.infinity || minY == double.infinity) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }

    final double width = max(maxX - minX, 1);
    final double height = max(maxY - minY, 1);
    return Rect.fromLTWH(minX - padding, minY - padding, width + padding * 2, height + padding * 2);
  }

  @override
  void dispose() {
    _service.removeListener(_serviceListener);
    super.dispose();
  }

  void _modifyMonitor(String name, MonitorLayout Function(MonitorLayout monitor) transform) {
    bool updated = false;
    _monitors = _monitors.map((monitor) {
      if (monitor.name == name) {
        updated = true;
        return transform(monitor);
      }
      return monitor;
    }).toList();

    if (updated) {
      _dirty = true;
      final MonitorLayout? refreshed = _findMonitorByName(name);
      _selected = refreshed ?? _selected;
      notifyListeners();
    }
  }

  void _handleServiceChanged() {
    _syncFromService(includeLiveMonitors: !_dirty);
  }

  void _syncFromService({bool resetSelection = false, required bool includeLiveMonitors}) {
    _layouts = _service.layouts;
    _activeLayoutId = _service.lastAppliedLayout?.id;

    if (includeLiveMonitors) {
      _monitors = _service.liveMonitorLayouts.map((monitor) => monitor.copyWith()).toList();
      if (_monitors.isEmpty) {
        _selected = null;
      } else if (resetSelection || _selected == null) {
        _selected = _monitors.first;
      } else {
        final MonitorLayout? existing = _selected != null ? _findMonitorByName(_selected!.name) : null;
        _selected = existing ?? _monitors.first;
      }
    } else {
      final MonitorLayout? current = _selected != null ? _findMonitorByName(_selected!.name, monitors: _monitors) : null;
      _selected = current ?? (_monitors.isNotEmpty ? _monitors.first : null);
    }

    notifyListeners();
  }

  MonitorLayout? _findMonitorByName(String? name, {List<MonitorLayout>? monitors}) {
    if (name == null) {
      return null;
    }
    final List<MonitorLayout> source = monitors ?? _monitors;
    for (final MonitorLayout monitor in source) {
      if (monitor.name == name) {
        return monitor;
      }
    }
    return null;
  }

  MonitorLayout? _findPrimaryMonitor() {
    for (final MonitorLayout monitor in _monitors) {
      if (monitor.isPrimary) {
        return monitor;
      }
    }
    return null;
  }

  DisplayLayout? _findLayoutById(String id) {
    for (final DisplayLayout layout in _layouts) {
      if (layout.id == id) {
        return layout;
      }
    }
    return null;
  }
}

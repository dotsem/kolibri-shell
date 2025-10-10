import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ctl_models.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/models/display_layout.dart';
import 'package:hypr_flutter/services/display_layout_store.dart';

class DisplayManagerException implements Exception {
  DisplayManagerException(this.message, {this.command, this.stderr});

  final String message;
  final List<String>? command;
  final String? stderr;

  @override
  String toString() {
    if (command == null) {
      return 'DisplayManagerException: $message';
    }
    return 'DisplayManagerException: $message (command: ${command!.join(' ')})';
  }
}

class DisplayManagerService extends ChangeNotifier {
  DisplayManagerService._internal();

  static final DisplayManagerService _instance = DisplayManagerService._internal();
  factory DisplayManagerService() => _instance;

  static const String liveLayoutId = '_live_layout';
  static const String liveLayoutLabel = 'Live layout';

  final DisplayLayoutStore _store = DisplayLayoutStore();

  bool _initialized = false;
  bool _initializing = false;
  bool _refreshing = false;
  bool _applying = false;

  DisplayLayoutsBundle _bundle = DisplayLayoutsBundle.empty();
  List<Monitor> _monitors = const <Monitor>[];

  StreamSubscription<DisplayLayoutsBundle>? _storeSubscription;
  StreamSubscription<HyprlandEvent>? _monitorAddedSubscription;
  StreamSubscription<HyprlandEvent>? _monitorRemovedSubscription;
  StreamSubscription<HyprlandEvent>? _focusedMonitorSubscription;
  Timer? _monitorRefreshDebounce;

  bool get isInitialized => _initialized;
  bool get isLoading => !_initialized || _initializing || _refreshing;
  bool get isApplying => _applying;

  List<Monitor> get monitors => List<Monitor>.unmodifiable(_monitors);
  List<MonitorLayout> get liveMonitorLayouts => _normalizePrimaryFlags(
        _monitors
            .map((monitor) => MonitorLayout.fromMonitor(monitor, isPrimary: monitor.focused))
            .toList(),
      );

  DisplayLayoutsBundle get bundle => _bundle;
  List<DisplayLayout> get layouts => List<DisplayLayout>.unmodifiable(_bundle.layouts);
  DisplayLayout? get lastAppliedLayout =>
      _bundle.lastAppliedLayoutId != null ? _findLayout(_bundle.lastAppliedLayoutId!) : null;

  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    notifyListeners();

    try {
      await _store.initialize();
      _bundle = await _store.loadBundle();
      _storeSubscription = _store.stream.listen((bundle) {
        _bundle = bundle;
        notifyListeners();
      });

      await _refreshMonitors();
      _subscribeToHyprEvents();
      _initialized = true;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _persistLayout(
    List<MonitorLayout> monitors, {
    required String id,
    required String label,
    bool setAsLastApplied = false,
  }) async {
    final DisplayLayout layout = DisplayLayout(
      id: id,
      label: label,
      monitors: monitors.map((monitor) => monitor.copyWith()).toList(),
      updatedAt: DateTime.now(),
    );

    final List<DisplayLayout> updatedLayouts = _upsertLayout(layout);
    _bundle = _bundle.copyWith(
      layouts: updatedLayouts,
      lastAppliedLayoutId: setAsLastApplied ? layout.id : _bundle.lastAppliedLayoutId,
    );

    await _store.saveBundle(_bundle);
  }

  Future<void> refreshMonitors() async {
    await initialize();
    await _refreshMonitors();
  }

  Future<void> applyLayoutById(String layoutId) async {
    await initialize();
    final DisplayLayout? layout = _findLayout(layoutId);
    if (layout == null) {
      throw DisplayManagerException('Layout "$layoutId" was not found in storage.');
    }
    await applyLayout(layout);
  }

  Future<void> applyLayout(DisplayLayout layout, {bool persistLastApplied = true}) async {
    await initialize();

    if (_applying) {
      return;
    }

    _applying = true;
    notifyListeners();

    try {
      final List<MonitorLayout> normalized = _normalizePrimaryFlags(layout.monitors);
      await _applyMonitorConfiguration(normalized);

      if (persistLastApplied) {
        final DisplayLayout normalizedLayout = layout.copyWith(monitors: normalized, updatedAt: DateTime.now());
        await _persistLayout(
          normalizedLayout.monitors,
          id: normalizedLayout.id,
          label: normalizedLayout.label,
          setAsLastApplied: true,
        );
      }

      await _refreshMonitors();
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  Future<void> applyLiveLayout(List<MonitorLayout> monitors) async {
    await initialize();

    if (_applying) {
      return;
    }

    _applying = true;
    notifyListeners();

    try {
      final List<MonitorLayout> normalized = _normalizePrimaryFlags(monitors);
      await _applyMonitorConfiguration(normalized);
      await _persistLayout(normalized, id: liveLayoutId, label: liveLayoutLabel, setAsLastApplied: true);
      await _refreshMonitors();
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  Future<DisplayLayout> snapshotCurrentLayout({required String id, String? label}) async {
    await initialize();
    await _refreshMonitors();

    final List<MonitorLayout> monitors = liveMonitorLayouts;
    return DisplayLayout(
      id: id,
      label: label ?? id,
      monitors: monitors,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveLayout(DisplayLayout layout, {bool setAsLastApplied = false}) async {
    await initialize();

    final DisplayLayout normalized = layout.copyWith(
      monitors: _normalizePrimaryFlags(layout.monitors),
      updatedAt: DateTime.now(),
    );
    await _persistLayout(
      normalized.monitors,
      id: normalized.id,
      label: normalized.label,
      setAsLastApplied: setAsLastApplied,
    );
    notifyListeners();
  }

  Future<void> deleteLayout(String id) async {
    await initialize();

    final List<DisplayLayout> remaining = _bundle.layouts.where((layout) => layout.id != id).toList();
    String? lastApplied = _bundle.lastAppliedLayoutId;
    if (lastApplied == id) {
      lastApplied = remaining.isNotEmpty ? remaining.first.id : null;
    }

    _bundle = _bundle.copyWith(layouts: remaining, lastAppliedLayoutId: lastApplied);
    await _store.saveBundle(_bundle);
    notifyListeners();
  }

  @override
  void dispose() {
    _monitorRefreshDebounce?.cancel();
    _storeSubscription?.cancel();
    _monitorAddedSubscription?.cancel();
    _monitorRemovedSubscription?.cancel();
    _focusedMonitorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshMonitors() async {
    if (_refreshing) {
      return;
    }

    _refreshing = true;
    notifyListeners();

    try {
      _monitors = await hyprCtl.getMonitors();
    } catch (error, stackTrace) {
      _log('Failed to refresh monitors: $error');
      _log(stackTrace.toString());
      _monitors = const <Monitor>[];
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _subscribeToHyprEvents() {
    try {
      _monitorAddedSubscription = hyprIpc.getEventStream(HyprlandEventType.monitoradded).listen((_) {
        _scheduleMonitorRefresh();
      });
      _monitorRemovedSubscription = hyprIpc.getEventStream(HyprlandEventType.monitorremoved).listen((_) {
        _scheduleMonitorRefresh();
      });
      _focusedMonitorSubscription = hyprIpc.getEventStream(HyprlandEventType.focusedmon).listen((_) {
        _scheduleMonitorRefresh();
      });
    } catch (error) {
      _log('Failed to subscribe to Hyprland IPC events: $error');
    }
  }

  void _scheduleMonitorRefresh() {
    _monitorRefreshDebounce?.cancel();
    _monitorRefreshDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_refreshMonitors());
    });
  }

  Future<void> _applyMonitorConfiguration(List<MonitorLayout> monitors) async {
    final List<Monitor> currentMonitors = await hyprCtl.getMonitors();
    final Set<String> targetedMonitors = <String>{};
    final List<Future<void> Function()> commandQueue = <Future<void> Function()>[];

    for (final MonitorLayout monitor in monitors) {
      targetedMonitors.add(monitor.name);

      if (!monitor.enabled) {
        commandQueue.add(() => _runHyprctl(<String>['keyword', 'monitor', '${monitor.name},disable']));
        continue;
      }

      if (monitor.isMirror) {
        final String? source = monitor.mirrorSource;
        if (source == null || source.isEmpty) {
          _log('Monitor ${monitor.name} requested mirror mode but no source provided. Disabling.');
          commandQueue.add(() => _runHyprctl(<String>['keyword', 'monitor', '${monitor.name},disable']));
        } else {
          commandQueue.add(() => _runHyprctl(<String>['keyword', 'monitor', '${monitor.name},mirror,$source']));
        }
        continue;
      }

      final String refresh = _formatRefreshRate(monitor.refreshRate);
      final String offset = '${monitor.x}x${monitor.y}';
      final String scale = monitor.scale.toStringAsFixed(2);
      final String spec = '${monitor.name},${monitor.width}x${monitor.height}@$refresh,$offset,$scale';
      commandQueue.add(() => _runHyprctl(<String>['keyword', 'monitor', spec]));
    }

    for (final Monitor monitor in currentMonitors) {
      if (!targetedMonitors.contains(monitor.name)) {
        commandQueue.add(() => _runHyprctl(<String>['keyword', 'monitor', '${monitor.name},disable']));
      }
    }

    for (final Future<void> Function() command in commandQueue) {
      await command();
    }

    MonitorLayout? primary;
    for (final MonitorLayout monitor in monitors) {
      if (monitor.enabled && monitor.isPrimary) {
        primary = monitor;
        break;
      }
    }
    if (primary == null) {
      for (final MonitorLayout monitor in monitors) {
        if (monitor.enabled) {
          primary = monitor;
          break;
        }
      }
    }
    primary ??= monitors.isNotEmpty ? monitors.first : null;

    if (primary != null) {
      await _runHyprctl(<String>['dispatch', 'focusmonitor', primary.name]);
    }
  }

  Future<void> _runHyprctl(List<String> args) async {
    final ProcessResult result = await Process.run('hyprctl', args);
    if (result.exitCode != 0) {
      throw DisplayManagerException(
        'hyprctl failed with exit code ${result.exitCode}: ${result.stderr}'.trim(),
        command: <String>['hyprctl', ...args],
        stderr: result.stderr is String ? result.stderr as String : result.stderr?.toString(),
      );
    }
  }

  List<DisplayLayout> _upsertLayout(DisplayLayout layout) {
    final List<DisplayLayout> updated = List<DisplayLayout>.from(_bundle.layouts);
    final int index = updated.indexWhere((item) => item.id == layout.id);
    if (index >= 0) {
      updated[index] = layout;
    } else {
      updated.add(layout);
    }
    updated.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return updated;
  }

  List<MonitorLayout> _normalizePrimaryFlags(List<MonitorLayout> monitors) {
    if (monitors.isEmpty) {
      return monitors;
    }

    final List<MonitorLayout> normalized = <MonitorLayout>[];
    bool primaryAssigned = false;
    final bool requestedPrimary = monitors.any((monitor) => monitor.enabled && monitor.isPrimary);

    for (final MonitorLayout monitor in monitors) {
      bool markPrimary = false;
      if (monitor.enabled) {
        if (requestedPrimary) {
          if (monitor.isPrimary && !primaryAssigned) {
            markPrimary = true;
          }
        } else if (!primaryAssigned) {
          markPrimary = true;
        }
      }

      normalized.add(monitor.copyWith(isPrimary: markPrimary));
      if (markPrimary) {
        primaryAssigned = true;
      }
    }

    if (!primaryAssigned) {
      normalized[0] = normalized[0].copyWith(isPrimary: normalized[0].enabled);
    }

    return normalized;
  }

  DisplayLayout? _findLayout(String id) {
    for (final DisplayLayout layout in _bundle.layouts) {
      if (layout.id == id) {
        return layout;
      }
    }
    return null;
  }

  String _formatRefreshRate(double refresh) {
    if (refresh <= 0) {
      return 'auto';
    }
    final double rounded = refresh.roundToDouble();
    if ((refresh - rounded).abs() < 0.001) {
      return rounded.toStringAsFixed(0);
    }
    return refresh.toStringAsFixed(2);
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DisplayManager] $message');
    }
  }
}

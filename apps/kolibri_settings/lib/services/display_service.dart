import 'dart:io';
import 'dart:convert';
import '../models/display_config.dart';

/// Service for managing display/monitor configuration via hyprctl
class DisplayService {
  DisplayService._();
  static final DisplayService instance = DisplayService._();

  /// Get all connected monitors from hyprctl
  Future<List<Monitor>> getMonitors() async {
    try {
      final result = await Process.run('hyprctl', ['monitors', '-j']);

      if (result.exitCode != 0) {
        throw Exception('hyprctl failed: ${result.stderr}');
      }

      final List<dynamic> jsonList = jsonDecode(result.stdout as String) as List;
      return jsonList.map((json) => Monitor.fromHyprctl(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error getting monitors: $e');
      return [];
    }
  }

  /// Apply a monitor configuration
  Future<bool> applyMonitorConfig(MonitorConfig config) async {
    try {
      final command = _generateHyprctlCommand(config);
      print('[DisplayService] Applying: hyprctl keyword monitor $command');
      final result = await Process.run('hyprctl', ['keyword', 'monitor', command]);

      if (result.exitCode != 0) {
        print('[DisplayService] Failed to apply monitor config: ${result.stderr}');
        return false;
      }

      print('[DisplayService] Successfully applied: $command');
      return true;
    } catch (e) {
      print('[DisplayService] Error applying monitor config: $e');
      return false;
    }
  }

  /// Apply a full display configuration
  Future<bool> applyDisplayConfig(DisplayConfig config) async {
    try {
      for (final monitor in config.monitors) {
        final success = await applyMonitorConfig(monitor);
        if (!success) {
          print('Failed to apply config for monitor ${monitor.name}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error applying display config: $e');
      return false;
    }
  }

  /// Generate hyprctl monitor command from config
  /// Format: name,resolution@rate,position,scale,transform
  String _generateHyprctlCommand(MonitorConfig config) {
    if (!config.enabled) {
      return '${config.name},disable';
    }

    final resolution = '${config.resolution.width}x${config.resolution.height}';
    final rate = config.refreshRate.toStringAsFixed(2);
    final position = '${config.position.x}x${config.position.y}';
    final scale = config.scale.toStringAsFixed(2);
    final transform = (config.rotation ~/ 90); // 0, 1, 2, 3 for 0°, 90°, 180°, 270°

    var command = '${config.name},$resolution@$rate,$position,$scale';

    if (transform != 0) {
      command += ',transform,$transform';
    }

    if (config.mirror != null) {
      command += ',mirror,${config.mirror}';
    }

    return command;
  }

  /// Reload Hyprland configuration
  Future<bool> reloadConfig() async {
    try {
      final result = await Process.run('hyprctl', ['reload']);
      return result.exitCode == 0;
    } catch (e) {
      print('Error reloading config: $e');
      return false;
    }
  }

  /// Test if hyprctl is available
  Future<bool> isHyprlandAvailable() async {
    try {
      final result = await Process.run('which', ['hyprctl']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get the currently focused monitor
  Future<String?> getFocusedMonitor() async {
    try {
      final monitors = await getMonitors();
      final focused = monitors.where((m) => m.focused).firstOrNull;
      return focused?.name;
    } catch (e) {
      print('Error getting focused monitor: $e');
      return null;
    }
  }

  /// Create a DisplayConfig from current monitor state
  Future<DisplayConfig> getCurrentDisplayConfig() async {
    try {
      final monitors = await getMonitors();
      final focusedName = await getFocusedMonitor();

      final monitorConfigs = monitors.map((m) {
        return m.toMonitorConfig(isPrimary: m.name == focusedName);
      }).toList();

      return DisplayConfig(monitors: monitorConfigs);
    } catch (e) {
      print('Error getting current display config: $e');
      return DisplayConfig(monitors: []);
    }
  }
}

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

  /// Save current mirror state to cache
  Future<bool> saveMirrorState() async {
    try {
      final scriptPath = '${Platform.environment['HOME']}/.config/hypr/hyprmulti-monitor-workspace-support/src/mirrorCache.sh';
      final result = await Process.run(scriptPath, ['save']);
      print('[DisplayService] Mirror state saved: ${result.stdout}');
      return result.exitCode == 0;
    } catch (e) {
      print('[DisplayService] Error saving mirror state: $e');
      return false;
    }
  }

  /// Restore mirror state from cache
  Future<bool> restoreMirrorState() async {
    try {
      final scriptPath = '${Platform.environment['HOME']}/.config/hypr/hyprmulti-monitor-workspace-support/src/mirrorCache.sh';
      final result = await Process.run(scriptPath, ['restore']);
      print('[DisplayService] Mirror state restored: ${result.stdout}');
      return result.exitCode == 0;
    } catch (e) {
      print('[DisplayService] Error restoring mirror state: $e');
      return false;
    }
  }

  /// Handle workspace reorganization after mirror change
  Future<bool> reorganizeAfterMirrorChange() async {
    try {
      final scriptPath = '${Platform.environment['HOME']}/.config/hypr/hyprmulti-monitor-workspace-support/src/handleMirrorChange.sh';
      final result = await Process.run(scriptPath, ['reorganize']);
      print('[DisplayService] Workspaces reorganized: ${result.stdout}');
      return result.exitCode == 0;
    } catch (e) {
      print('[DisplayService] Error reorganizing workspaces: $e');
      return false;
    }
  }

  /// Detect mirror changes between two configurations
  Map<String, String?> detectMirrorChanges(DisplayConfig oldConfig, DisplayConfig newConfig) {
    final changes = <String, String?>{};

    for (final newMonitor in newConfig.monitors) {
      final oldMonitor = oldConfig.monitors.where((m) => m.name == newMonitor.name).firstOrNull;

      if (oldMonitor != null && oldMonitor.mirror != newMonitor.mirror) {
        changes[newMonitor.name] = newMonitor.mirror;
      }
    }

    return changes;
  }

  /// Apply display configuration with mirror change handling
  Future<bool> applyDisplayConfigWithMirrorHandling(DisplayConfig oldConfig, DisplayConfig newConfig) async {
    try {
      // Save current mirror state before changes
      await saveMirrorState();

      // Detect mirror changes
      final mirrorChanges = detectMirrorChanges(oldConfig, newConfig);

      // Apply the configuration
      final success = await applyDisplayConfig(newConfig);

      if (!success) {
        print('[DisplayService] Failed to apply config, restoring mirror state');
        await restoreMirrorState();
        return false;
      }

      // If there were mirror changes, reorganize workspaces
      if (mirrorChanges.isNotEmpty) {
        print('[DisplayService] Mirror changes detected: $mirrorChanges');
        await Future.delayed(Duration(milliseconds: 500)); // Let changes settle
        await reorganizeAfterMirrorChange();
      }

      return true;
    } catch (e) {
      print('[DisplayService] Error applying config with mirror handling: $e');
      return false;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hypr_flutter/hyprland/ctl_models.dart';

// Forward declaration for the main IPC class

// Hyprland Control Class (Actions)
class HyprlandCtl {
  /// Execute hyprctl command (for actions)
  static Future<String> runHyprctlCommand(String command) async {
    try {
      final result = await Process.run('hyprctl', command.split(' '));
      if (result.exitCode != 0) {
        throw Exception('hyprctl failed: ${result.stderr}');
      }
      return result.stdout.toString();
    } catch (e) {
      throw Exception('Failed to execute hyprctl: $e');
    }
  }

  /// Helper methods for common commands
  Future<void> switchToWorkspace(int id) async {
    await runHyprctlCommand('dispatch workspace $id');
  }

  Future<void> moveToWorkspace(int id) async {
    await runHyprctlCommand('dispatch movetoworkspace $id');
  }

  Future<Workspace> getActiveWorkspace() async {
    return Workspace.fromJson(jsonDecode(await runHyprctlCommand('-j activeworkspace')));
  }

  Future<List<Monitor>> getMonitors() async {
    List<dynamic> monitors = jsonDecode(await runHyprctlCommand('-j monitors'));
    return monitors.map((e) => Monitor.fromJson(e)).toList();
  }

  Future<List<Workspace>> getWorkspaces() async {
    List<dynamic> workspaces = jsonDecode(await runHyprctlCommand('-j workspaces'));
    return workspaces.map((e) => Workspace.fromJson(e)).toList();
  }

  Future<List<Client>> getClients() async {
    List<dynamic> clients = jsonDecode(await runHyprctlCommand('-j clients'));
    return clients.map((e) => Client.fromJson(e)).toList();
  }
  // Future<void> _dispatch(String cmd, [String? args]) async {
  //   await Process.run("sh", ["-c", cmd, args ?? ""]);
  // }

  // Future<void> batch(List<String> commands) async {
  //   final batchCommand = commands.map((cmd) => cmd.startsWith('dispatch ') ? cmd : 'dispatch $cmd').join('; ');
  //   await _dispatch('--batch "$batchCommand"');
  // }

  // // ============================================
  // // WORKSPACE ACTIONS
  // // ============================================

  // /// Switch to workspace by ID
  // Future<void> switchToWorkspace(int workspaceId) async {
  //   await _dispatch('workspace', workspaceId.toString());
  // }

  // /// Switch to workspace by name
  // Future<void> switchToWorkspaceByName(String name) async {
  //   await _dispatch('workspace', 'name:$name');
  // }

  // /// Switch to previous workspace
  // Future<void> switchToPreviousWorkspace() async {
  //   await _dispatch('workspace', 'previous');
  // }

  // /// Switch to next workspace
  // Future<void> switchToNextWorkspace() async {
  //   await _dispatch('workspace', '+1');
  // }

  // /// Switch to previous workspace (relative)
  // Future<void> switchToWorkspaceRelative(int offset) async {
  //   final sign = offset >= 0 ? '+' : '';
  //   await _dispatch('workspace', '$sign$offset');
  // }

  // /// Switch to next workspace on monitor
  // Future<void> switchToNextWorkspaceOnMonitor() async {
  //   await _dispatch('workspace', 'm+1');
  // }

  // /// Switch to previous workspace on monitor
  // Future<void> switchToPreviousWorkspaceOnMonitor() async {
  //   await _dispatch('workspace', 'm-1');
  // }

  // /// Switch to next empty workspace
  // Future<void> switchToNextEmptyWorkspace() async {
  //   await _dispatch('workspace', 'empty');
  // }

  // /// Create and switch to new workspace
  // Future<void> createWorkspace([String? name]) async {
  //   if (name != null) {
  //     await _dispatch('workspace', 'name:$name');
  //   } else {
  //     await _dispatch('workspace', 'empty');
  //   }
  // }

  // // ============================================
  // // WINDOW ACTIONS
  // // ============================================

  // /// Close the active window
  // Future<void> closeActiveWindow() async {
  //   await _dispatch('killactive');
  // }

  // /// Close window by address
  // Future<void> closeWindow(String address) async {
  //   await _dispatch('closewindow', 'address:$address');
  // }

  // /// Close window by class
  // Future<void> closeWindowByClass(String className) async {
  //   await _dispatch('closewindow', 'class:$className');
  // }

  // /// Close window by title
  // Future<void> closeWindowByTitle(String title) async {
  //   await _dispatch('closewindow', 'title:$title');
  // }

  // /// Focus window by address
  // Future<void> focusWindow(String address) async {
  //   await _dispatch('focuswindow', 'address:$address');
  // }

  // /// Focus window by class
  // Future<void> focusWindowByClass(String className) async {
  //   await _dispatch('focuswindow', 'class:$className');
  // }

  // /// Focus window by title
  // Future<void> focusWindowByTitle(String title) async {
  //   await _dispatch('focuswindow', 'title:$title');
  // }

  // /// Move focus in direction
  // Future<void> moveFocus(String direction) async {
  //   // direction: l, r, u, d (left, right, up, down)
  //   await _dispatch('movefocus', direction);
  // }

  // /// Move active window to workspace
  // Future<void> moveWindowToWorkspace(int workspaceId) async {
  //   await _dispatch('movetoworkspace', workspaceId.toString());
  // }

  // /// Move active window to workspace by name
  // Future<void> moveWindowToWorkspaceByName(String name) async {
  //   await _dispatch('movetoworkspace', 'name:$name');
  // }

  // /// Move active window silently to workspace (don't switch)
  // Future<void> moveWindowToWorkspaceSilent(int workspaceId) async {
  //   await _dispatch('movetoworkspacesilent', workspaceId.toString());
  // }

  // /// Move window in direction
  // Future<void> moveWindow(String direction) async {
  //   // direction: l, r, u, d (left, right, up, down)
  //   await _dispatch('movewindow', direction);
  // }

  // /// Swap window with another in direction
  // Future<void> swapWindow(String direction) async {
  //   await _dispatch('swapwindow', direction);
  // }

  // /// Toggle window floating
  // Future<void> toggleFloating([String? window]) async {
  //   if (window != null) {
  //     await _dispatch('togglefloating', window);
  //   } else {
  //     await _dispatch('togglefloating');
  //   }
  // }

  // /// Toggle window fullscreen
  // Future<void> toggleFullscreen([int mode = 0]) async {
  //   // mode: 0 = maximize, 1 = fullscreen, 2 = maximize keep aspect ratio
  //   await _dispatch('fullscreen', mode.toString());
  // }

  // /// Pin window (show on all workspaces)
  // Future<void> pinWindow([String? window]) async {
  //   if (window != null) {
  //     await _dispatch('pin', window);
  //   } else {
  //     await _dispatch('pin');
  //   }
  // }

  // /// Resize active window
  // Future<void> resizeActiveWindow(int deltaX, int deltaY) async {
  //   await _dispatch('resizeactive', '$deltaX $deltaY');
  // }

  // /// Move active window
  // Future<void> moveActiveWindow(int deltaX, int deltaY) async {
  //   await _dispatch('moveactive', '$deltaX $deltaY');
  // }

  // /// Center window
  // Future<void> centerWindow() async {
  //   await _dispatch('centerwindow');
  // }

  // // ============================================
  // // SPECIAL WORKSPACE ACTIONS
  // // ============================================

  // /// Toggle special workspace
  // Future<void> toggleSpecialWorkspace([String? name]) async {
  //   if (name != null) {
  //     await _dispatch('togglespecialworkspace', name);
  //   } else {
  //     await _dispatch('togglespecialworkspace');
  //   }
  // }

  // /// Move window to special workspace
  // Future<void> moveToSpecialWorkspace([String? name]) async {
  //   if (name != null) {
  //     await _dispatch('movetoworkspace', 'special:$name');
  //   } else {
  //     await _dispatch('movetoworkspace', 'special');
  //   }
  // }

  // // ============================================
  // // MONITOR ACTIONS
  // // ============================================

  // /// Focus monitor by name
  // Future<void> focusMonitor(String monitor) async {
  //   await _dispatch('focusmonitor', monitor);
  // }

  // /// Move workspace to monitor
  // Future<void> moveWorkspaceToMonitor(int workspaceId, String monitor) async {
  //   await _dispatch('moveworkspacetomonitor', '$workspaceId $monitor');
  // }

  // /// Swap active workspaces between monitors
  // Future<void> swapActiveWorkspaces(String monitor1, String monitor2) async {
  //   await _dispatch('swapactiveworkspaces', '$monitor1 $monitor2');
  // }

  // /// Toggle DPMS (monitor power)
  // Future<void> toggleDPMS() async {
  //   await _dispatch('dpms', 'toggle');
  // }

  // /// Turn monitor off
  // Future<void> turnMonitorOff() async {
  //   await _dispatch('dpms', 'off');
  // }

  // /// Turn monitor on
  // Future<void> turnMonitorOn() async {
  //   await _dispatch('dpms', 'on');
  // }

  // // ============================================
  // // LAYOUT ACTIONS
  // // ============================================

  // /// Cycle window layouts
  // Future<void> cycleNext() async {
  //   await _dispatch('cyclenext');
  // }

  // /// Cycle window layouts (previous)
  // Future<void> cyclePrev() async {
  //   await _dispatch('cyclenext', 'prev');
  // }

  // /// Toggle window split
  // Future<void> toggleSplit() async {
  //   await _dispatch('togglesplit');
  // }

  // /// Switch to next layout
  // Future<void> nextLayout() async {
  //   await _dispatch('layoutmsg', 'next');
  // }

  // /// Switch to previous layout
  // Future<void> previousLayout() async {
  //   await _dispatch('layoutmsg', 'prev');
  // }

  // // ============================================
  // // APPLICATION ACTIONS
  // // ============================================

  // /// Execute command
  // Future<void> exec(String command) async {
  //   await _dispatch('exec', command);
  // }

  // /// Execute command and close after
  // Future<void> execr(String command) async {
  //   await _dispatch('execr', command);
  // }

  // /// Launch application
  // Future<void> launchApp(String app, [Map<String, String>? rules]) async {
  //   if (rules != null && rules.isNotEmpty) {
  //     final ruleStrings = rules.entries.map((e) => '${e.key}:${e.value}').toList();
  //     await _dispatch('exec', '[${ruleStrings.join(';')}] $app');
  //   } else {
  //     await _dispatch('exec', app);
  //   }
  // }

  // /// Launch terminal
  // Future<void> launchTerminal([String? terminal]) async {
  //   await exec(terminal ?? 'kitty');
  // }

  // /// Launch application launcher
  // Future<void> launchAppLauncher([String? launcher]) async {
  //   await exec(launcher ?? 'wofi --show drun');
  // }

  // // ============================================
  // // SYSTEM ACTIONS
  // // ============================================

  // /// Reload Hyprland configuration
  // Future<void> reload() async {
  //   await _dispatch('forcerendererreload');
  // }

  // /// Exit Hyprland
  // Future<void> exit() async {
  //   await _dispatch('exit');
  // }

  // /// Lock screen
  // Future<void> lockScreen([String? locker]) async {
  //   await exec(locker ?? 'swaylock');
  // }

  // // ============================================
  // // GROUP/TAB ACTIONS
  // // ============================================

  // /// Toggle group (tabbed windows)
  // Future<void> toggleGroup() async {
  //   await _dispatch('togglegroup');
  // }

  // /// Change to next tab in group
  // Future<void> changeGroupActive(String direction) async {
  //   // direction: f (forward), b (backward)
  //   await _dispatch('changegroupactive', direction);
  // }

  // /// Focus urgent window
  // Future<void> focusUrgent() async {
  //   await _dispatch('focusurgent');
  // }

  // // ============================================
  // // ANIMATION ACTIONS
  // // ============================================

  // /// Force redraw
  // Future<void> forceRedraw() async {
  //   await _dispatch('forcerendererreload');
  // }

  // // ============================================
  // // UTILITY ACTIONS
  // // ============================================

  // /// Notify with system notification
  // Future<void> notify(String title, String message, [String? icon, int timeout = 5000]) async {
  //   final iconArg = icon != null ? '-i $icon' : '';
  //   final timeoutArg = '-t $timeout';
  //   await exec('notify-send $iconArg $timeoutArg "$title" "$message"');
  // }

  // /// Take screenshot
  // Future<void> screenshot([String? area, String? output]) async {
  //   final cmd = StringBuffer('grim');
  //   if (area != null) {
  //     if (area == 'selection') {
  //       cmd.write(' -g "\$(slurp)"');
  //     } else if (area == 'window') {
  //       cmd.write(' -g "\$(hyprctl activewindow -j | jq -r \'.at[0],.at[1],.size[0],.size[1]\' | paste -sd \'x+\' | sed \'s/x/ /2;s/+/ /\')"');
  //     }
  //   }
  //   if (output != null) {
  //     cmd.write(' $output');
  //   } else {
  //     cmd.write(' ~/Pictures/screenshot-\$(date +%Y-%m-%d-%H%M%S).png');
  //   }
  //   await exec(cmd.toString());
  // }

  // /// Create custom workspace setup
  // Future<void> setupWorkspaceLayout({required int workspaceId, String? name, List<String>? applications, bool switchTo = true}) async {
  //   final commands = <String>[];

  //   // Create/switch to workspace
  //   if (switchTo) {
  //     if (name != null) {
  //       commands.add('dispatch workspace name:$name');
  //     } else {
  //       commands.add('dispatch workspace $workspaceId');
  //     }
  //   }

  //   // Launch applications
  //   if (applications != null) {
  //     for (final app in applications) {
  //       commands.add('dispatch exec $app');
  //     }
  //   }

  //   if (commands.isNotEmpty) {
  //     await batch(commands);
  //   }
  // }

  // /// Quick workspace switcher (1-10)
  // Future<void> quickSwitchWorkspace(int number) async {
  //   if (number >= 1 && number <= 10) {
  //     await switchToWorkspace(number);
  //   }
  // }

  // /// Quick move window to workspace (1-10)
  // Future<void> quickMoveToWorkspace(int number) async {
  //   if (number >= 1 && number <= 10) {
  //     await moveWindowToWorkspace(number);
  //   }
  // }

  // // ============================================
  // // ADVANCED BATCH OPERATIONS
  // // ============================================

  // /// Setup gaming workspace with typical gaming applications
  // Future<void> setupGamingWorkspace([int workspaceId = 5]) async {
  //   await setupWorkspaceLayout(workspaceId: workspaceId, name: 'Gaming', applications: ['steam', 'discord', 'obs-studio'], switchTo: true);

  //   // Set performance settings
  //   await batch(['keyword animations:enabled false', 'keyword decoration:blur:enabled false', 'keyword general:gaps_in 0', 'keyword general:gaps_out 0']);
  // }

  // /// Setup development workspace
  // Future<void> setupDevWorkspace([int workspaceId = 2]) async {
  //   await setupWorkspaceLayout(workspaceId: workspaceId, name: 'Development', applications: ['code', 'firefox', 'kitty'], switchTo: true);
  // }

  // /// Setup media workspace
  // Future<void> setupMediaWorkspace([int workspaceId = 3]) async {
  //   await setupWorkspaceLayout(workspaceId: workspaceId, name: 'Media', applications: ['spotify', 'vlc', 'gimp'], switchTo: true);
  // }

  // /// Restore default settings
  // Future<void> restoreDefaults() async {
  //   await batch(['keyword animations:enabled true', 'keyword decoration:blur:enabled true', 'keyword general:gaps_in 5', 'keyword general:gaps_out 10', 'keyword general:border_size 2']);
  // }

  // /// Toggle performance mode (disable effects for better performance)
  // Future<void> togglePerformanceMode([bool enable = true]) async {
  //   if (enable) {
  //     await batch(['keyword animations:enabled false', 'keyword decoration:blur:enabled false', 'keyword decoration:drop_shadow false', 'keyword general:gaps_in 0']);
  //     await notify('Performance Mode', 'Enabled - Effects disabled for better performance');
  //   } else {
  //     await restoreDefaults();
  //     await notify('Performance Mode', 'Disabled - Effects restored');
  //   }
  // }
}

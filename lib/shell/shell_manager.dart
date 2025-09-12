// shell/shell_manager.dart
import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/models/screen_edge.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/window_ids.dart';

class ShellManager {
  static final ShellManager _instance = ShellManager._internal();
  factory ShellManager() => _instance;
  ShellManager._internal();

  final MethodChannel _sharedChannel = MethodChannel('shell_communication');
  final List<String> _createdWindows = [];

  List<String> get createdWindows => List.unmodifiable(_createdWindows);

  void initialize() {
    _setupSharedCommunication();
  }

  void _setupSharedCommunication() {
    _sharedChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'window_created':
          _createdWindows.add(call.arguments['windowId']);
          break;
        case 'window_destroyed':
          _createdWindows.remove(call.arguments['windowId']);
          break;
      }
    });
  }

  Future<void> createShellWindows() async {
    // int monitorCount = (await hyprIPC.getMonitors()).length;
    int monitorCount = 3;
    try {
      for (int i = 1; i < monitorCount; i++) {
        await createTaskbar(monitorIndex: i);
        WindowIds.taskbars.add("taskbar_$i");
      }

      // Create left sidebar
      await createLeftSidebar();

      // Create right sidebar
      await createRightSidebar();
    } catch (e) {
      print('Error creating shell windows: $e');
    }
  }

  Future<void> createTaskbar({required int monitorIndex}) async {
    final windowId = "taskbar_$monitorIndex";

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Taskbar-$monitorIndex", isLayer: true, width: 1920, height: 48, args: ["--class=taskbar", "--name=$windowId", "--window-type=taskbar"]);
    await FlLinuxWindowManager.instance.enableLayerAutoExclusive(windowId: windowId);

    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.right.value, windowId: windowId);
    await FlLinuxWindowManager.instance.setMonitor(monitorId: monitorIndex, windowId: windowId);
    await _createSharedChannel(windowId);
  }

  Future<void> createLeftSidebar() async {
    const windowId = WindowIds.leftSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Left Sidebar", isLayer: true, width: 200, height: 1032, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=left"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.bottom.value, windowId: windowId);
    await _createSharedChannel(windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
  }

  Future<void> createRightSidebar() async {
    const windowId = WindowIds.rightSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Right Sidebar", isLayer: true, width: 200, height: 1032, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=right"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.right.value | ScreenEdge.bottom.value, windowId: windowId);
    await _createSharedChannel(windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
  }

  Future<void> _createSharedChannel(String windowId) async {
    await FlLinuxWindowManager.instance.createSharedMethodChannel(channelName: "shell_communication", shareWithWindowId: "main", windowId: windowId);
  }

  void sendMessageToWindow(String windowId, String method, [dynamic args]) {
    _sharedChannel.invokeMethod(method, {'targetWindow': windowId, 'data': args});
  }
}

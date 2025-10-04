import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/models/keyboard_mode.dart';
import 'package:fl_linux_window_manager/models/screen_edge.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/window_ids.dart';
import 'package:hypr_flutter/services/clock.dart';

class ShellManager {
  // Singleton to ensure only ONE method channel handler is registered
  static final ShellManager _instance = ShellManager._internal();
  factory ShellManager() => _instance;

  final List<String> _createdWindows = [];
  bool _isInitialized = false;

  ShellManager._internal();

  List<String> get createdWindows => List.unmodifiable(_createdWindows);

  final MethodChannel _shellCom = MethodChannel('shell_communication');

  Future<void> initialize({bool isMainWindow = false}) async {
    // Only set up once per isolate
    if (!_isInitialized) {
      _setupSharedCommunication();
      _isInitialized = true;
    }

    // Initialize services (each isolate runs its own)
    ClockService().initialize();

    if (isMainWindow) {
      print("ShellManager: MAIN window initialized");
    } else {
      print("ShellManager: SECONDARY window initialized");
    }
  }

  void _setupSharedCommunication() {
    print("ShellManager: Setting up shared communication handler");
    _shellCom.setMethodCallHandler((call) async {
      // Only log non-clock messages to reduce spam
      if (call.method != 'broadcast_clock') {
        print("Received call: ${call.method} with args: ${call.arguments}");
      }

      switch (call.method) {
        case 'window_created':
          _createdWindows.add(call.arguments['windowId']);
          break;
        case 'window_destroyed':
          _createdWindows.remove(call.arguments['windowId']);
          break;
        case 'ping':
          // reply to the sender
          return 'pong from window ${call.arguments['windowId']}';
        case 'broadcast_clock':
          // Not used - each isolate runs its own services
          break;
      }
    });
  }

  Future<void> createShellWindows() async {
    int monitorCount = (await hyprCtl.getMonitors()).length;
    try {
      for (int i = 1; i < monitorCount; i++) {
        await createTaskbar(monitorIndex: i);
        WindowIds.taskbars.add("taskbar_$i");
      }

      // Create left sidebar
      await createLeftSidebar();

      // Create right sidebar
      await createRightSidebar();

      // Create music player
      await createMusicPlayer();
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
    FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createLeftSidebar() async {
    const windowId = WindowIds.leftSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Left Sidebar", isLayer: true, width: 200, height: 1032, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=left"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.bottom.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
    FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createRightSidebar() async {
    const windowId = WindowIds.rightSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Right Sidebar", isLayer: true, width: 500, height: 1018, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=right"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.right.value | ScreenEdge.bottom.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
    await FlLinuxWindowManager.instance.setLayerMargin(top: 8, left: 8, right: 8, bottom: 8, windowId: windowId);
    FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createMusicPlayer() async {
    const windowId = WindowIds.musicPlayer;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Right Sidebar", isLayer: true, width: musicPlayerWidth, height: 180, args: ["--class=musicPlayer", "--name=$windowId", "--window-type=popup"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
    FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> _createSharedChannel(String windowId) async {
    await FlLinuxWindowManager.instance.createSharedMethodChannel(channelName: "shell_communication", shareWithWindowId: "main", windowId: windowId);
  }

  void sendMessageToWindow(String windowId, String method, [dynamic args]) {
    _shellCom.invokeMethod(method, {'targetWindow': windowId, 'data': args});
  }
}

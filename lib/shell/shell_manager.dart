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

  final Set<String> _createdWindows = <String>{};
  final Map<String, Future<void>> _creationInFlight = <String, Future<void>>{};
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
    print("ShellManager: Creating shell windows for $monitorCount monitors");

    try {
      // Create taskbars for additional monitors (only if not already created)
      for (int i = 1; i < monitorCount; i++) {
        final windowId = "taskbar_$i";
        if (!_createdWindows.contains(windowId) && !_creationInFlight.containsKey(windowId)) {
          _creationInFlight[windowId] = createTaskbar(monitorIndex: i);
          await _creationInFlight[windowId];
          _creationInFlight.remove(windowId);
          WindowIds.taskbars.add(windowId);
        }
      }

      // Create other windows only if they don't exist
      if (!_createdWindows.contains(WindowIds.leftSidebar) && !_creationInFlight.containsKey(WindowIds.leftSidebar)) {
        _creationInFlight[WindowIds.leftSidebar] = createLeftSidebar();
        await _creationInFlight[WindowIds.leftSidebar];
        _creationInFlight.remove(WindowIds.leftSidebar);
      }

      if (!_createdWindows.contains(WindowIds.rightSidebar) && !_creationInFlight.containsKey(WindowIds.rightSidebar)) {
        _creationInFlight[WindowIds.rightSidebar] = createRightSidebar();
        await _creationInFlight[WindowIds.rightSidebar];
        _creationInFlight.remove(WindowIds.rightSidebar);
      }

      if (!_createdWindows.contains(WindowIds.musicPlayer) && !_creationInFlight.containsKey(WindowIds.musicPlayer)) {
        _creationInFlight[WindowIds.musicPlayer] = createMusicPlayer();
        await _creationInFlight[WindowIds.musicPlayer];
        _creationInFlight.remove(WindowIds.musicPlayer);
      }

      if (!_createdWindows.contains(WindowIds.menu) && !_creationInFlight.containsKey(WindowIds.menu)) {
        _creationInFlight[WindowIds.menu] = createMenu();
        await _creationInFlight[WindowIds.menu];
        _creationInFlight.remove(WindowIds.menu);
      }
    } catch (e) {
      print('Error creating shell windows: $e');
    }
  }

  Future<void> createTaskbar({required int monitorIndex}) async {
    final windowId = "taskbar_$monitorIndex";

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Taskbar-$monitorIndex", isLayer: true, width: 1000, height: taskbarHeight, args: ["--class=taskbar", "--name=$windowId", "--window-type=taskbar"]);
    await FlLinuxWindowManager.instance.enableLayerAutoExclusive(windowId: windowId);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.right.value, windowId: windowId);
    await FlLinuxWindowManager.instance.setMonitor(monitorId: monitorIndex, windowId: windowId);
    await FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false, windowId: windowId);
    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createMenu() async {
    const windowId = WindowIds.menu;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Menu", isLayer: true, width: 800, height: 600, args: ["--class=menu", "--name=$windowId", "--window-type=popup"]);
    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.exclusive, windowId: windowId);
    await FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false, windowId: windowId);
    await FlLinuxWindowManager.instance.enableLayerAutoExclusive(windowId: windowId);
    await FlLinuxWindowManager.instance.enableTransparency(windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createLeftSidebar() async {
    const windowId = WindowIds.leftSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Left Sidebar", isLayer: true, width: 500, height: 500, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=left"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.bottom.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
    await FlLinuxWindowManager.instance.setLayerMargin(top: 8, left: 8, right: 8, bottom: 8, windowId: windowId);
    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);
    await FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createRightSidebar() async {
    const windowId = WindowIds.rightSidebar;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Right Sidebar", isLayer: true, width: 500, height: 500, args: ["--class=sidebar", "--name=$windowId", "--window-type=sidebar", "--position=right"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.right.value | ScreenEdge.bottom.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);
    await FlLinuxWindowManager.instance.setLayerMargin(top: 8, left: 8, right: 8, bottom: 8, windowId: windowId);
    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);
    await FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false, windowId: windowId);
    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.onDemand, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> createMusicPlayer() async {
    const windowId = WindowIds.musicPlayer;

    await FlLinuxWindowManager.instance.createWindow(windowId: windowId, title: "Music player", isLayer: true, width: musicPlayerWidth, height: musicPlayerWidth, args: ["--class=musicPlayer", "--name=$windowId", "--window-type=popup"]);
    await FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value, windowId: windowId);
    await FlLinuxWindowManager.instance.hideWindow(windowId: windowId);

    await FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none, windowId: windowId);
    await FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false, windowId: windowId);

    await _createSharedChannel(windowId);
  }

  Future<void> _createSharedChannel(String windowId) async {
    await FlLinuxWindowManager.instance.createSharedMethodChannel(channelName: "shell_communication", shareWithWindowId: "main", windowId: windowId);
  }

  void sendMessageToWindow(String windowId, String method, [dynamic args]) {
    _shellCom.invokeMethod(method, {'targetWindow': windowId, 'data': args});
  }
}

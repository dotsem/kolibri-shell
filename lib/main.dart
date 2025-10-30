import 'dart:async';
import 'dart:io';

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/models/layer.dart';
import 'package:fl_linux_window_manager/models/screen_edge.dart';
import 'package:fl_linux_window_manager/models/keyboard_mode.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/services/app_catalog.dart';
import 'package:hypr_flutter/services/dbus_service.dart';
import 'package:hypr_flutter/shell/shell_manager.dart';
import 'package:hypr_flutter/shell/shell_router.dart';
import 'package:hypr_flutter/window_ids.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:pipewire_song_info/pipewire_song_info.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Store args for later use
  initialArgs.addAll(args);

  // final streams = await Pipewire.getAvailableStreams();
  // for (final stream in streams) {
  //   print(stream.applicationName);
  //   print(stream.applicationId);
  //   print(stream.isActive);
  // }

  // config for taskbar on window 0 (default)
  if (args.isEmpty) {
    await AppCatalogService().initialize();
    print("app catalog loaded");

    FlLinuxWindowManager.instance.setLayer(WindowLayer.top);
    FlLinuxWindowManager.instance.setSize(width: 1920, height: 50);
    FlLinuxWindowManager.instance.setTitle(title: "Taskbar-0");
    WindowIds.taskbars.add("main");
    FlLinuxWindowManager.instance.setKeyboardInteractivity(KeyboardMode.none);
    FlLinuxWindowManager.instance.enableLayerAutoExclusive();
    FlLinuxWindowManager.instance.setIsDecorated(isDecorated: false);

    FlLinuxWindowManager.instance.setLayerAnchor(anchor: ScreenEdge.top.value | ScreenEdge.left.value | ScreenEdge.right.value);
    FlLinuxWindowManager.instance.setMonitor(monitorId: 0);
  }

  print("args: $args");
  if (args.isEmpty) {
    runApp(HyprlandShellApp(windowId: "main"));
  } else {
    runApp(HyprlandShellApp(windowId: args[1].split("=")[1]));
  }
}

class HyprlandShellApp extends StatefulWidget {
  final String windowId;
  const HyprlandShellApp({super.key, required this.windowId});

  @override
  State<HyprlandShellApp> createState() => _HyprlandShellAppState();
}

class _HyprlandShellAppState extends State<HyprlandShellApp> {
  late ShellManager _shellManager;
  int _currentMonitorCount = 0;
  bool _isRestarting = false;

  void createPanels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        _shellManager.createShellWindows();
      });
    });
  }

  Future<void> _handleMonitorChange() async {
    if (_isRestarting) return;

    try {
      final monitors = await hyprCtl.getMonitors();
      final newMonitorCount = monitors.length;

      print("Monitor change detected: $_currentMonitorCount -> $newMonitorCount");

      // If monitor was removed, we need to handle it carefully
      if (newMonitorCount < _currentMonitorCount) {
        print("Monitor removed - scheduling graceful restart...");
        _isRestarting = true;

        // Use a delayed restart to avoid GPU context issues
        Future.delayed(Duration(milliseconds: 500), () {
          // Exit gracefully - systemd or hyprland will restart us
          exit(0);
        });
        return;
      }

      // If monitor was added, create new panels
      if (newMonitorCount > _currentMonitorCount) {
        print("Monitor added - creating new panels...");
        _currentMonitorCount = newMonitorCount;
        createPanels();
      }
    } catch (e) {
      print("Error handling monitor change: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _shellManager = ShellManager();

    // Main window (no args or windowId == "main") is the controller
    final isMainWindow = widget.windowId == "main";
    _shellManager.initialize(isMainWindow: isMainWindow);

    // Only main window creates additional windows and initializes DBus
    if (isMainWindow) {
      // Get initial monitor count
      hyprCtl.getMonitors().then((monitors) {
        _currentMonitorCount = monitors.length;
      });

      createPanels();
      // Initialize DBus service for remote control
      HyprPanelDBusService.instance
          .initialize()
          .then((_) {
            debugPrint('DBus service initialized');
          })
          .catchError((error) {
            debugPrint('Failed to initialize DBus service: $error');
          });
    }

    if (isMainWindow) {
      hyprIpc.getEventStream(HyprlandEventType.monitoradded).listen((event) {
        _handleMonitorChange();
      });
      hyprIpc.getEventStream(HyprlandEventType.monitorremoved).listen((event) {
        _handleMonitorChange();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellRouter(args: initialArgs);
  }
}

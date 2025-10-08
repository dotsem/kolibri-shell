import 'dart:async';

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/models/layer.dart';
import 'package:fl_linux_window_manager/models/screen_edge.dart';
import 'package:fl_linux_window_manager/models/keyboard_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/services/app_catalog.dart';
import 'package:hypr_flutter/shell/shell_manager.dart';
import 'package:hypr_flutter/shell/shell_router.dart';
import 'package:hypr_flutter/window_ids.dart';
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

  void createPanels() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        _shellManager.createShellWindows();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _shellManager = ShellManager();

    // Main window (no args or windowId == "main") is the controller
    final isMainWindow = widget.windowId == "main";
    _shellManager.initialize(isMainWindow: isMainWindow);

    // Only main window creates additional windows
    if (isMainWindow) {
      createPanels();
    }

    if (isMainWindow) {
      hyprIpc.getEventStream(HyprlandEventType.monitoradded).listen((event) {
        createPanels();
      });
      hyprIpc.getEventStream(HyprlandEventType.monitorremoved).listen((event) {
        createPanels();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellRouter(args: initialArgs);
  }
}

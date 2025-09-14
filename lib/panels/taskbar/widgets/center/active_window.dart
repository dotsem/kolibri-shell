import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';

class ActiveWindow extends StatefulWidget {
  const ActiveWindow({super.key});

  @override
  State<ActiveWindow> createState() => _ActiveWindowState();
}

class _ActiveWindowState extends State<ActiveWindow> {
  final HyprlandIpcManager hyprIPC = HyprlandIpcManager.instance;
  StreamSubscription<HyprlandEvent>? _windowTitleSubscription;
  String appName = "None";
  String windowTitle = "None";

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _windowTitleSubscription = hyprIPC
        .getEventStream(HyprlandEventType.activewindow)
        .listen((event) => _updateWindowTitle(event));
  }

  void _updateWindowTitle(HyprlandEvent event) {
    setState(() {
      appName = event.data[0];
      windowTitle = event.data[1];
    });
  }

  void dispose() {
    _windowTitleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(appName, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.scrim)),
        Text(windowTitle),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/services/window_icon_resolver.dart';

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
  WindowIconData _iconData = WindowIconData.empty;
  final WindowIconResolver _iconResolver = WindowIconResolver.instance;

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
    final String updatedAppName = event.data[0];
    final String updatedTitle = event.data[1];
    _iconResolver.resolve(updatedAppName).then((icon) {
      if (!mounted) return;
      setState(() {
        appName = updatedAppName;
        windowTitle = updatedTitle;
        _iconData = icon;
      });
    });
  }

  void dispose() {
    _windowTitleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color headingColor = Theme.of(context).colorScheme.scrim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _iconResolver.buildIcon(
          _iconData,
          size: 28,
          borderRadius: 8,
          fallbackIcon: Icons.apps,
          fallbackColor: headingColor,
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appName, style: TextStyle(fontSize: 10, color: headingColor), overflow: TextOverflow.ellipsis),
            Text(windowTitle, overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }
}

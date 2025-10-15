import 'dart:async';

import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/services/window_icon_resolver.dart';
import 'package:hypr_flutter/widgets/animated/slide_fade_transition.dart';

class ActiveWindow extends StatefulWidget {
  final double width;
  const ActiveWindow({super.key, required this.width});

  @override
  State<ActiveWindow> createState() => _ActiveWindowState();
}

class _ActiveWindowState extends State<ActiveWindow> with SingleTickerProviderStateMixin {
  final HyprlandIpcManager hyprIPC = HyprlandIpcManager.instance;
  StreamSubscription<HyprlandEvent>? _windowTitleSubscription;
  String appName = "None";
  String windowTitle = "None";
  WindowIconData _iconData = WindowIconData.empty;
  final WindowIconResolver _iconResolver = WindowIconResolver.instance;
  bool hovered = false;

  late ColorTween _colorTween;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
  }

  void _subscribeToEvents() {
    _windowTitleSubscription = hyprIPC.getEventStream(HyprlandEventType.activewindow).listen((event) => _updateWindowTitle(event));
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

  @override
  void dispose() {
    _windowTitleSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colorTween = ColorTween(begin: Theme.of(context).colorScheme.onPrimaryContainer, end: Theme.of(context).colorScheme.primary);

    final Color headingColor = Theme.of(context).colorScheme.scrim;
    return InputRegion(
      child: MouseRegion(
        onEnter: (event) {
          setState(() {
            hovered = true;
          });
          _controller.forward();
        },
        onExit: (event) {
          setState(() {
            hovered = false;
          });
          _controller.reverse();
        },

        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            foregroundColor: Colors.transparent,
          ),
          onPressed: () {},
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.primaryContainer),
            width: widget.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconResolver.buildIcon(_iconData, size: 28, borderRadius: 8, fallbackIcon: Icons.apps, fallbackColor: headingColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: TextStyle(fontSize: 10, color: headingColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),

                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) => Text(
                            windowTitle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(color: _colorTween.evaluate(_controller)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SlideFadeTransition(
                    visible: hovered,
                    direction: SlideDirection.right,
                    duration: _controller.duration!,
                    child: Icon(Icons.apps_rounded, color: Theme.of(context).colorScheme.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

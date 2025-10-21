import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/services/window_icon_resolver.dart';
import 'package:hypr_flutter/widgets/animated/slide_fade_transition.dart';
import 'package:hypr_flutter/window_ids.dart';

class ActiveWindow extends StatefulWidget {
  final double width;
  final int monitorIndex;
  const ActiveWindow({super.key, required this.width, required this.monitorIndex});

  @override
  State<ActiveWindow> createState() => _ActiveWindowState();
}

class _ActiveWindowState extends State<ActiveWindow> with SingleTickerProviderStateMixin {
  final HyprlandIpcManager hyprIPC = HyprlandIpcManager.instance;
  StreamSubscription<HyprlandEvent>? _windowTitleSubscription;
  StreamSubscription<HyprlandEvent>? _focusedMonSubscription;
  String appName = "None";
  String windowTitle = "None";
  WindowIconData _iconData = WindowIconData.empty;
  final WindowIconResolver _iconResolver = WindowIconResolver.instance;
  bool hovered = false;
  bool isMonitorActive = false;
  String? _currentMonitorName;

  late ColorTween _colorTween;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _loadMonitorInfo();
    _subscribeToEvents();
  }

  Future<void> _loadMonitorInfo() async {
    // Get current monitor info from Hyprland
    try {
      final result = await Process.run('hyprctl', ['monitors', '-j']);
      if (result.exitCode == 0) {
        final monitors = jsonDecode(result.stdout as String) as List;
        if (widget.monitorIndex < monitors.length) {
          final monitor = monitors[widget.monitorIndex];
          _currentMonitorName = monitor['name'] as String;

          // Check if this monitor is currently focused
          final focused = monitor['focused'] as bool? ?? false;
          if (mounted) {
            setState(() {
              isMonitorActive = focused;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading monitor info: $e');
    }
  }

  void _subscribeToEvents() {
    // Listen to activewindow events - this fires on EVERY window change
    _windowTitleSubscription = hyprIPC.getEventStream(HyprlandEventType.activewindow).listen((event) {
      _updateWindowTitle(event);
      _checkIfWindowIsOnThisMonitor(); // Check if the new active window is on this monitor
    });

    // Listen to focusedmon events - this fires when monitor focus changes
    _focusedMonSubscription = hyprIPC.getEventStream(HyprlandEventType.focusedmon).listen((event) => _updateFocusedMonitor(event));
  }

  Future<void> _checkIfWindowIsOnThisMonitor() async {
    // Check if the currently active window is on this monitor
    try {
      final result = await Process.run('hyprctl', ['activewindow', '-j']);
      if (result.exitCode == 0) {
        final activeWindow = jsonDecode(result.stdout as String);
        final windowMonitor = activeWindow['monitor'] as int? ?? -1;

        if (mounted) {
          setState(() {
            isMonitorActive = (windowMonitor == widget.monitorIndex);
          });
        }
      }
    } catch (e) {
      // Silently handle errors - might be no active window
    }
  }

  void _updateFocusedMonitor(HyprlandEvent event) {
    // focusedmon event data: [monitorName, workspaceName]
    if (event.data.isEmpty) return;

    final monitorName = event.data[0];

    if (mounted) {
      setState(() {
        isMonitorActive = (_currentMonitorName == monitorName);
      });
    }
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
    _focusedMonSubscription?.cancel();
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
          onPressed: () {
            FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.menu);
          },
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.primaryContainer),
            width: widget.width,
            child: Stack(
              children: [
                if (isMonitorActive)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: isMonitorActive ? 1.0 : 0.0,
                      child: Container(
                        width: 300,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Theme.of(context).colorScheme.primaryContainer.withOpacity(0.0), Theme.of(context).colorScheme.primary.withOpacity(0.25), Theme.of(context).colorScheme.primary.withOpacity(0.5)],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
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
                        child: Icon(Icons.apps_rounded, color: Theme.of(context).colorScheme.secondary, size: 30),
                      ),
                    ],
                  ),
                ),

                // Gradient overlay (only visible when monitor is active)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

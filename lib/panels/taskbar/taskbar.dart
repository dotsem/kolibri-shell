import 'dart:async';

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/center/active_window.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/music/music.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/battery.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/clock.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/systray.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/workspaces/workspaces.dart';

import '../../shell/shell_manager.dart';
import '../../window_ids.dart';
import 'widgets/sidebar_toggle_button.dart';

class TaskbarWidget extends StatefulWidget {
  final String windowId;
  final int monitorIndex;
  const TaskbarWidget({super.key, required this.windowId, required this.monitorIndex});

  @override
  State<TaskbarWidget> createState() => _TaskbarWidgetState();
}

class _TaskbarWidgetState extends State<TaskbarWidget> {
  final ShellManager _shellManager = ShellManager();

  final GlobalKey musicPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() async {
        while (true) {
          final context = musicPlayerKey.currentContext;
          final windowUsed = await FlLinuxWindowManager.instance.isWindowIdUsed(WindowIds.musicPlayer);

          if (context != null && windowUsed) {
            final box = context.findRenderObject() as RenderBox;
            final position = box.localToGlobal(Offset.zero);
            FlLinuxWindowManager.instance.setLayerMargin(left: position.dx.toInt(), top: -taskbarHeight, windowId: WindowIds.musicPlayer);
            break;
          }

          await Future.delayed(const Duration(milliseconds: 10));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      canRequestFocus: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            height: 48,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface),
            child: Stack(
              alignment: AlignmentGeometry.center,
              children: [
                Positioned(
                  left: 0,
                  child: Row(
                    children: [
                      SidebarToggleButton(
                        widget: SvgPicture.asset("assets/icons/arch-symbolic.svg", colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), height: 28, width: 28),
                        sidebarId: WindowIds.leftSidebar,
                        taskbarId: widget.windowId,
                        windowId: widget.windowId,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, right: 8),
                        child: Workspaces(monitorIndex: widget.monitorIndex),
                      ),
                      MusicPanel(key: musicPlayerKey),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
                    child: ActiveWindow(width: 500, monitorIndex: widget.monitorIndex),
                  ),
                ),

                Positioned(
                  right: 0,
                  child: Row(
                    children: [
                      Padding(padding: const EdgeInsets.only(left: 4, right: 4), child: BatteryIndicator()),

                      Padding(padding: const EdgeInsets.only(left: 4, right: 4), child: Clock()),

                      SidebarToggleButton(widget: SystemTrayWidget(), sidebarId: WindowIds.rightSidebar, taskbarId: widget.windowId, windowId: widget.windowId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

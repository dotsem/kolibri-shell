import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/music_player/music_player.dart';
import 'package:hypr_flutter/panels/sidebar_left/sidebar_left.dart';
import 'package:hypr_flutter/panels/sidebar_right/sidebar_right.dart';
import 'package:hypr_flutter/panels/taskbar/taskbar.dart';
import 'package:hypr_flutter/windows/settings/settings_window.dart';
import 'package:hypr_flutter/window_ids.dart';

class ShellRouter extends StatelessWidget {
  final List<String> args;

  const ShellRouter({Key? key, required this.args}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String windowType = _getWindowType();

    String windowId = _getWindowId();
    switch (windowType) {
      case 'taskbar':
        return TaskbarWidget(windowId: windowId, monitorIndex: _getMonitorIndex());
      case 'left_sidebar':
        return LeftSidebarWidget();
      case 'right_sidebar':
        return RightSidebarWidget();
      case 'music_player':
        return MusicPlayerWidget();
      case 'settings':
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SettingsWindow(),
        );
      default:
        return TaskbarWidget(windowId: windowId, monitorIndex: _getMonitorIndex()); // Default to taskbar for main window
    }
  }

  String _getWindowType() {
    if (args.contains('--window-type=sidebar')) {
      if (args.contains('--position=left')) return 'left_sidebar';
      if (args.contains('--position=right')) return 'right_sidebar';
    } else if (args.contains('--window-type=popup')) {
      if (args.contains('--class=musicPlayer')) return 'music_player';
    } else if (args.contains('--class=settings') || args.contains('--name=${WindowIds.settings}')) {
      return 'settings';
    }
    return 'taskbar'; // Default
  }

  String _getWindowId() {
    for (String arg in args) {
      if (arg.startsWith('--name=')) {
        return arg.split('=')[1];
      }
    }
    return "main";
  }

  int _getMonitorIndex() {
    String windowId = _getWindowId();
    if (windowId.startsWith("taskbar_")) {
      return int.parse(windowId.split("_")[1]);
    }
    return 0;
  }
}

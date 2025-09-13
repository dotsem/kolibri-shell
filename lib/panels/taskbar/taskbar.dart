import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/color/dark.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return InputRegion.negative(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            height: 48,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface),
            child: Row(
              children: [
                SidebarToggleButton(
                  icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.surface),
                  sidebarId: WindowIds.leftSidebar,
                  taskbarId: widget.windowId,
                ),
                Workspaces(monitorIndex: widget.monitorIndex),
                Spacer(),
                Text(widget.windowId),
                Spacer(),
                _buildAppLauncher(),
                SystemTrayWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppLauncher() {
    return InputRegion(
      child: IconButton(
        icon: Icon(Icons.apps, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () {
          print("App launcher clicked");
          // Handle app launcher
        },
      ),
    );
  }

  Widget _buildDebugControls() {
    if (_shellManager.createdWindows.isNotEmpty) return SizedBox.shrink();

    return InputRegion(
      child: ElevatedButton(
        onPressed: () => _shellManager.createShellWindows(),
        child: Text('Create Shell', style: TextStyle(fontSize: 10)),
      ),
    );
  }
}

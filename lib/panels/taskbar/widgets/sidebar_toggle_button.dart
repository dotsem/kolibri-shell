import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';

class SidebarToggleButton extends StatelessWidget {
  final Widget widget;
  final String sidebarId;
  final String taskbarId;
  const SidebarToggleButton({super.key, required this.widget, required this.sidebarId, required this.taskbarId});

  @override
  Widget build(BuildContext context) {
    return InputRegion(
      child: IconButton(
        onPressed: () async {
          if (await FlLinuxWindowManager.instance.isVisible(windowId: sidebarId)) {
            await FlLinuxWindowManager.instance.hideWindow(windowId: sidebarId);
          } else {
            await FlLinuxWindowManager.instance.showWindow(windowId: sidebarId);
          }
          await FlLinuxWindowManager.instance.setFocus(windowId: taskbarId);
        },
        icon: widget,
      ),
    );
  }
}

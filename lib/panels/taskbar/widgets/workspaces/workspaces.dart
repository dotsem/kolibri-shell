import 'dart:async';

import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/config.dart' as config;
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ctl_models.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/workspaces/active_workspace.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class Workspaces extends StatefulWidget {
  final int monitorIndex;
  const Workspaces({super.key, required this.monitorIndex});

  @override
  State<Workspaces> createState() => _WorkspacesState();
}

class _WorkspacesState extends State<Workspaces> {
  final HyprlandIpcManager hyprIPC = HyprlandIpcManager.instance;
  StreamSubscription<HyprlandEvent>? _workspaceSubscription;
  StreamSubscription<HyprlandEvent>? _openWindowSubscription;
  StreamSubscription<HyprlandEvent>? _closeWindowSubscription;
  StreamSubscription<HyprlandEvent>? _moveWindowSubscription;

  late int monitorOffset;
  int currentWorkspace = 0;
  final double workspaceSize = 30;
  List<bool> busyWorkspaces = List.filled(10, false);

  void initState() {
    super.initState();
    monitorOffset = (widget.monitorIndex * config.workspacesPerMonitor);
    _subscribeToEvents();
    updateBusyWorkspaces();
    hyprCtl.getMonitors().then((monitors) {
      setState(() {
        currentWorkspace = monitors[widget.monitorIndex].activeWorkspace["id"];
      });
    });
  }

  bool inMonitorScope(int workspaceId) {
    return workspaceId > monitorOffset &&
        workspaceId <= monitorOffset + config.workspacesPerMonitor;
  }

  Future<void> updateBusyWorkspaces() async {
    List<Workspace> workspaces = await hyprCtl.getWorkspaces();
    busyWorkspaces = List.filled(10, false);
    for (Workspace workspace in workspaces) {
      int id = workspace.id;
      if (inMonitorScope(id) && workspace.windows > 0) {
        busyWorkspaces[id - monitorOffset - 1] = true;
      }
    }
    setState(() {
      busyWorkspaces = busyWorkspaces.toList();
    });
  }

  void _subscribeToEvents() {
    _workspaceSubscription = hyprIPC
        .getEventStream(HyprlandEventType.workspace)
        .listen(_updateWorkspace);

    _openWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.openwindow)
        .listen((event) => updateBusyWorkspaces());

    _closeWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.closewindow)
        .listen((event) => updateBusyWorkspaces());

    _moveWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.movewindow)
        .listen((event) => updateBusyWorkspaces());
  }

  void _updateWorkspace(HyprlandEvent event) {
    int workspaceId = int.tryParse(event.data.first) ?? 1;
    if (inMonitorScope(workspaceId)) {
      setState(() => currentWorkspace = int.tryParse(event.data.first) ?? 1);
    }
  }

  @override
  void dispose() {
    _workspaceSubscription?.cancel();
    _openWindowSubscription?.cancel();
    _closeWindowSubscription?.cancel();
    _moveWindowSubscription?.cancel();
    super.dispose();
  }

  BorderRadius getBusyBorderRadius(int workspaceId) {
    Radius topLeft = Radius.circular(workspaceSize / 2);
    Radius topRight = Radius.circular(workspaceSize / 2);
    Radius bottomLeft = Radius.circular(workspaceSize / 2);
    Radius bottomRight = Radius.circular(workspaceSize / 2);
    if (workspaceId > 0 && busyWorkspaces[workspaceId - 1]) {
      topLeft = Radius.zero;
      bottomLeft = Radius.zero;
    }
    if (workspaceId < config.workspacesPerMonitor - 1 && busyWorkspaces[workspaceId + 1]) {
      topRight = Radius.zero;
      bottomRight = Radius.zero;
    }

    return BorderRadius.only(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        Row(
          children: [
            for (int i = 0; i < busyWorkspaces.length; i++)
              (busyWorkspaces[i])
                  ? Container(
                      width: workspaceSize,
                      height: workspaceSize,
                      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: getBusyBorderRadius(i),
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    )
                  : SizedBox(width: workspaceSize, height: workspaceSize),
          ],
        ),
        // Container(
        //   width: workspaceSize - 4,
        //   height: workspaceSize - 4,
        //   margin: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        //   transform: Matrix4.translation(
        //     Vector3.array([
        //       (workspaceSize * (currentWorkspace - 1 - (10 * widget.monitorIndex))),
        //       0,
        //       0,
        //     ]),
        //   ),
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(workspaceSize / 2),
        //     color: Theme.of(context).colorScheme.primary,
        //   ),
        // ),
        ActiveWorkspace(
          workspaceSize: workspaceSize,
          currentIndex: (currentWorkspace - 1) - monitorOffset,
        ),

        Row(
          children: [
            for (int i = monitorOffset + 1; i <= monitorOffset + 10; i++)
              InputRegion(
                child: Container(
                  width: workspaceSize,
                  height: workspaceSize,
                  margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  child: IconButton(
                    onPressed: () {
                      hyprCtl.switchToWorkspace(i);
                    },

                    icon: Text(
                      '$i',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

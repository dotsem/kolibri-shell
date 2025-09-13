import 'dart:async';

import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/config.dart' as config;
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ctl_models.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
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
    return workspaceId > monitorOffset && workspaceId <= monitorOffset + config.workspacesPerMonitor;
  }

  Future<void> updateBusyWorkspaces() async {
    List<Workspace> workspaces = await hyprCtl.getWorkspaces();

    busyWorkspaces = List.filled(10, false);
    for (Workspace workspace in workspaces) {
      int id = workspace.id;
      if (inMonitorScope(id)) {
        setState(() {
          busyWorkspaces[id - monitorOffset - 1] = true;
        });
      }
    }
  }

  void _subscribeToEvents() {
    _workspaceSubscription = hyprIPC.getEventStream(HyprlandEventType.workspace).listen(_updateWorkspace);

    _openWindowSubscription = hyprIPC.getEventStream(HyprlandEventType.openwindow).listen((event) => updateBusyWorkspaces());

    _closeWindowSubscription = hyprIPC.getEventStream(HyprlandEventType.closewindow).listen((event) => updateBusyWorkspaces());
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        Row(
          children: [
            for (int i = monitorOffset + 1; i <= monitorOffset + 10; i++)
              if (busyWorkspaces[i - monitorOffset - 1])
                Container(
                  width: workspaceSize,
                  height: workspaceSize,
                  margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(workspaceSize / 2), color: Theme.of(context).colorScheme.primaryContainer),
                ),
          ],
        ),
        Container(
          width: workspaceSize - 4,
          height: workspaceSize - 4,
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          transform: Matrix4.translation(Vector3.array([(workspaceSize * (currentWorkspace - 1 - (10 * widget.monitorIndex))), 0, 0])),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(workspaceSize / 2), color: Theme.of(context).colorScheme.primary),
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

                    icon: Text('$i', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 12)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

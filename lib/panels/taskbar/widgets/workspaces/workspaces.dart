import 'dart:async';
import 'dart:io';

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
  List<String?> occupiedWorkspaces = List.filled(10, null);

  void initState() {
    super.initState();
    monitorOffset = (widget.monitorIndex * config.workspacesPerMonitor);
    _subscribeToEvents();
    updateOccupiedWorkspaces();
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

  Future<void> updateOccupiedWorkspaces() async {
    List<Client> workspacesClients = await hyprCtl.getClients();
    occupiedWorkspaces = List.filled(10, null);
    Set<int> handledWorkspaceIds = {};
    for (Client client in workspacesClients) {
      int id = client.workspace["id"];
      if (inMonitorScope(id) && !handledWorkspaceIds.contains(id)) {
        occupiedWorkspaces[id - monitorOffset - 1] = client.clientClass;
        handledWorkspaceIds.add(id);
      }
    }
    setState(() {
      occupiedWorkspaces = occupiedWorkspaces.toList();
    });
  }

  void _subscribeToEvents() {
    _workspaceSubscription = hyprIPC
        .getEventStream(HyprlandEventType.workspace)
        .listen(_updateWorkspace);

    _openWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.openwindow)
        .listen((event) => updateOccupiedWorkspaces());

    _closeWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.closewindow)
        .listen((event) => updateOccupiedWorkspaces());

    _moveWindowSubscription = hyprIPC
        .getEventStream(HyprlandEventType.movewindow)
        .listen((event) => updateOccupiedWorkspaces());
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
    if (workspaceId > 0 && occupiedWorkspaces[workspaceId - 1] != null) {
      topLeft = Radius.zero;
      bottomLeft = Radius.zero;
    }
    if (workspaceId < config.workspacesPerMonitor - 1 &&
        occupiedWorkspaces[workspaceId + 1] != null) {
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
            for (int i = 0; i < occupiedWorkspaces.length; i++)
              (occupiedWorkspaces[i] != null)
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

                    icon:
                        // (occupiedWorkspaces[i - monitorOffset - 1] != null)
                        //     ? Image.file(
                        //         File(() {
                        //           print(occupiedWorkspaces[i - monitorOffset - 1]);
                        //           return appIcons[occupiedWorkspaces[i - monitorOffset - 1]] ?? "";
                        //         }()),
                        //         width: 20,
                        //         height: 20,
                        //       ):
                        Text(
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

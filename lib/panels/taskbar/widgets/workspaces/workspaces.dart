import 'dart:async';
import 'dart:io';

import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hypr_flutter/config/config.dart' as config;
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/hyprland/ctl_models.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/workspaces/active_workspace.dart';
import 'package:hypr_flutter/services/app_catalog.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class Workspaces extends StatefulWidget {
  final int monitorIndex;
  const Workspaces({super.key, required this.monitorIndex});

  @override
  State<Workspaces> createState() => _WorkspacesState();
}

class _WorkspacesState extends State<Workspaces> {
  final HyprlandIpcManager hyprIPC = HyprlandIpcManager.instance;
  final AppCatalogService _catalog = AppCatalogService();
  StreamSubscription<HyprlandEvent>? _workspaceSubscription;
  StreamSubscription<HyprlandEvent>? _openWindowSubscription;
  StreamSubscription<HyprlandEvent>? _closeWindowSubscription;
  StreamSubscription<HyprlandEvent>? _moveWindowSubscription;

  late int monitorOffset;
  int currentWorkspace = 0;
  final double workspaceSize = 30;
  List<_WorkspaceClient> occupiedWorkspaces = List<_WorkspaceClient>.generate(10, (_) => const _WorkspaceClient(), growable: false);
  final Map<String, String?> _iconPathCache = <String, String?>{};
  final Map<String, Widget?> _iconWidgetCache = <String, Widget?>{};

  void initState() {
    super.initState();
    if (!_catalog.isInitialized) {
      unawaited(_catalog.initialize());
    }
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
    return workspaceId > monitorOffset && workspaceId <= monitorOffset + config.workspacesPerMonitor;
  }

  Future<void> updateOccupiedWorkspaces() async {
    if (!_catalog.isInitialized) {
      await _catalog.initialize();
    }
    List<Client> workspacesClients = await hyprCtl.getClients();
    final List<_WorkspaceClient> nextState = List<_WorkspaceClient>.generate(10, (_) => const _WorkspaceClient(), growable: false);
    final Set<int> handledWorkspaceIds = <int>{};
    for (Client client in workspacesClients) {
      int id = client.workspace["id"];
      if (inMonitorScope(id) && !handledWorkspaceIds.contains(id)) {
        final String? clientClass = client.clientClass;
        final int workspaceIndex = id - monitorOffset - 1;
        if (workspaceIndex < 0 || workspaceIndex >= nextState.length) {
          handledWorkspaceIds.add(id);
          continue;
        }

        if (clientClass == null || clientClass.isEmpty) {
          nextState[workspaceIndex] = const _WorkspaceClient();
          handledWorkspaceIds.add(id);
          continue;
        }

        String? iconPath = _iconPathCache[clientClass];
        if (iconPath == null) {
          iconPath = await _catalog.iconPathForStartupClass(clientClass);
          _iconPathCache[clientClass] = iconPath;
        }

        nextState[workspaceIndex] = _WorkspaceClient(name: clientClass, iconPath: iconPath);
        handledWorkspaceIds.add(id);
      }
    }
    setState(() {
      occupiedWorkspaces = nextState;
    });
  }

  void _subscribeToEvents() {
    _workspaceSubscription = hyprIPC.getEventStream(HyprlandEventType.workspace).listen(_updateWorkspace);

    _openWindowSubscription = hyprIPC.getEventStream(HyprlandEventType.openwindow).listen((event) => updateOccupiedWorkspaces());

    _closeWindowSubscription = hyprIPC.getEventStream(HyprlandEventType.closewindow).listen((event) => updateOccupiedWorkspaces());

    _moveWindowSubscription = hyprIPC.getEventStream(HyprlandEventType.movewindow).listen((event) => updateOccupiedWorkspaces());
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
    if (workspaceId > 0 && occupiedWorkspaces[workspaceId - 1].name != null) {
      topLeft = Radius.zero;
      bottomLeft = Radius.zero;
    }
    if (workspaceId < config.workspacesPerMonitor - 1 && occupiedWorkspaces[workspaceId + 1].name != null) {
      topRight = Radius.zero;
      bottomRight = Radius.zero;
    }

    return BorderRadius.only(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        Row(
          children: [
            for (int i = 0; i < occupiedWorkspaces.length; i++)
              (occupiedWorkspaces[i].name != null)
                  ? Container(
                      width: workspaceSize,
                      height: workspaceSize,
                      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      decoration: BoxDecoration(borderRadius: getBusyBorderRadius(i), color: Theme.of(context).colorScheme.primaryContainer),
                    )
                  : SizedBox(width: workspaceSize, height: workspaceSize),
          ],
        ),
        ActiveWorkspace(workspaceSize: workspaceSize, currentIndex: (currentWorkspace - 1) - monitorOffset),

        Row(
          children: [
            for (int i = monitorOffset + 1; i <= monitorOffset + 10; i++)
              InputRegion(
                child: Container(
                  width: workspaceSize,
                  height: workspaceSize,
                  margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 2, end: i == currentWorkspace ? 8 : 0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, paddingValue, _) {
                      return IconButton(
                        padding: EdgeInsets.all(paddingValue),
                        onPressed: () {
                          hyprCtl.switchToWorkspace(i);
                        },
                        icon: _buildWorkspaceIcon(context, i),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkspaceIcon(BuildContext context, int workspaceIndex) {
    final int listIndex = workspaceIndex - monitorOffset - 1;
    final Color labelColor = Theme.of(context).colorScheme.onPrimaryContainer;

    if (listIndex < 0 || listIndex >= occupiedWorkspaces.length) {
      return _WorkspaceLabel(index: workspaceIndex, color: labelColor);
    }

    final _WorkspaceClient client = occupiedWorkspaces[listIndex];
    final String? name = client.name;
    if (name == null || name.isEmpty) {
      return _WorkspaceLabel(index: workspaceIndex, color: labelColor);
    }

    final String? iconPath = client.iconPath;
    if (iconPath != null && iconPath.isNotEmpty) {
      final String cacheKey = iconPath;
      Widget? iconWidget = _iconWidgetCache[cacheKey];
      iconWidget ??= _buildIconWidget(iconPath);
      if (iconWidget != null) {
        _iconWidgetCache[cacheKey] = iconWidget;
        return iconWidget;
      }
      debugPrint('Workspace icon fallback triggered for $name: path=$iconPath');
    }

    return _WorkspaceAppPlaceholder(color: labelColor);
  }
}

class _WorkspaceLabel extends StatelessWidget {
  const _WorkspaceLabel({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text('$index', style: TextStyle(color: color, fontSize: 12));
  }
}

class _WorkspaceClient {
  const _WorkspaceClient({this.name, this.iconPath});

  final String? name;
  final String? iconPath;

  _WorkspaceClient copyWith({String? name, String? iconPath}) {
    return _WorkspaceClient(name: name ?? this.name, iconPath: iconPath ?? this.iconPath);
  }
}

class _WorkspaceAppPlaceholder extends StatelessWidget {
  const _WorkspaceAppPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apps, color: color, size: 18);
  }
}

Widget? _buildIconWidget(String iconPath) {
  final file = File(iconPath);
  if (!file.existsSync()) {
    debugPrint('Workspace icon path missing: $iconPath');
    return null;
  }

  final lower = iconPath.toLowerCase();
  if (lower.endsWith('.svg') || lower.endsWith('.svgz')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SvgPicture.file(file, width: 20, height: 20, fit: BoxFit.contain),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.file(file, width: 20, height: 20, fit: BoxFit.contain),
  );
}

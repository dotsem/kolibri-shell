import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hypr_flutter/models/display_layout.dart';
import 'package:hypr_flutter/windows/settings/controllers/display_manager_controller.dart';

class DisplayManagerPage extends StatefulWidget {
  const DisplayManagerPage({super.key});

  @override
  State<DisplayManagerPage> createState() => _DisplayManagerPageState();
}

class _DisplayManagerPageState extends State<DisplayManagerPage> {
  late final DisplayManagerController _controller;
  String? _selectedLayoutId;

  @override
  void initState() {
    super.initState();
    _controller = DisplayManagerController();
    _controller.addListener(_onControllerChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_controller.layouts.any((layout) => layout.id == _selectedLayoutId)) {
        return;
      }
      _selectedLayoutId = _controller.activeLayoutId ?? _selectedLayoutId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.monitors.isEmpty) {
          return _buildEmptyState(context);
        }

        final ThemeData theme = Theme.of(context);
        final List<DisplayLayout> layouts = _controller.layouts;
        final String? dropdownValue = _selectedLayoutId != null &&
                layouts.any((layout) => layout.id == _selectedLayoutId)
            ? _selectedLayoutId
            : _controller.activeLayoutId;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LayoutToolbar(
                controller: _controller,
                layouts: layouts,
                selectedLayoutId: dropdownValue,
                onSelectLayout: (value) => setState(() => _selectedLayoutId = value),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _MonitorWorkspace(controller: _controller),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MonitorDetailsPanel(controller: _controller),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _controller.isApplying ? null : _controller.resetToLiveConfiguration,
                      icon: const Icon(Icons.undo),
                      label: const Text('Reset to current configuration'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _controller.isApplying ? null : _controller.applyChanges,
                      icon: _controller.isApplying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_controller.isApplying ? 'Applying…' : 'Apply to Hyprland'),
                    ),
                  ),
                ],
              ),
              if (_controller.hasPendingChanges)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Unsaved adjustments will be lost if you close settings.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monitor, size: 48),
          const SizedBox(height: 12),
          const Text('No monitors detected'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _controller.refreshLiveMonitors,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _LayoutToolbar extends StatefulWidget {
  const _LayoutToolbar({
    required this.controller,
    required this.layouts,
    required this.selectedLayoutId,
    required this.onSelectLayout,
  });

  final DisplayManagerController controller;
  final List<DisplayLayout> layouts;
  final String? selectedLayoutId;
  final ValueChanged<String?> onSelectLayout;

  @override
  State<_LayoutToolbar> createState() => _LayoutToolbarState();
}

class _LayoutToolbarState extends State<_LayoutToolbar> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLayouts = widget.layouts.isNotEmpty;
    final ThemeData theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                  child: DropdownButtonFormField<String>(
                    value: widget.selectedLayoutId,
                    decoration: const InputDecoration(labelText: 'Saved layouts'),
                    items: widget.layouts
                        .map(
                          (layout) => DropdownMenuItem<String>(
                            value: layout.id,
                            child: Text(layout.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      widget.onSelectLayout(value);
                      if (value != null) {
                        widget.controller.loadLayoutForEditing(value);
                      }
                    },
                    hint: const Text('Select layout'),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: hasLayouts && widget.selectedLayoutId != null
                      ? () => widget.controller.applyLayout(widget.selectedLayoutId!)
                      : null,
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Apply layout'),
                ),
                OutlinedButton.icon(
                  onPressed: hasLayouts && widget.selectedLayoutId != null
                      ? () => widget.controller.deleteLayout(widget.selectedLayoutId!)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                TextButton.icon(
                  onPressed: widget.controller.isApplying ? null : widget.controller.refreshLiveMonitors,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload monitors'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Save as new layout'),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.controller.monitors.isEmpty
                      ? null
                      : () {
                          final String name = _nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a layout name to save.')),
                            );
                            return;
                          }
                          final String id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                          widget.controller.saveLayout(id, name).then((_) {
                            widget.onSelectLayout(id);
                            _nameController.clear();
                          });
                        },
                  icon: const Icon(Icons.save),
                  label: const Text('Save layout'),
                ),
              ],
            ),
            if (widget.controller.hasPendingChanges)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'You have unsaved local changes. Save or apply to persist.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonitorWorkspace extends StatelessWidget {
  const _MonitorWorkspace({required this.controller});

  final DisplayManagerController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _MonitorCanvas(controller: controller),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: _MonitorList(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorList extends StatelessWidget {
  const _MonitorList({required this.controller});

  final DisplayManagerController controller;

  @override
  Widget build(BuildContext context) {
    final monitors = controller.monitors;
    final selected = controller.selectedMonitor;
    return ListView.separated(
      itemBuilder: (context, index) {
        final monitor = monitors[index];
        final bool isSelected = monitor.name == selected?.name;
        final ThemeData theme = Theme.of(context);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => controller.selectMonitor(monitor.name),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
              color: theme.colorScheme.surfaceVariant.withOpacity(isSelected ? 0.3 : 0.1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monitor.description,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${monitor.width}×${monitor.height} @ ${monitor.refreshRate.toStringAsFixed(0)}Hz',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Position: (${monitor.x}, ${monitor.y})  •  Scale: ${monitor.scale.toStringAsFixed(2)}x',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (monitor.isMirror)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Mirroring ${monitor.mirrorSource ?? '-'}'),
                  ),
                if (monitor.isPrimary)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Primary display', style: TextStyle(color: theme.colorScheme.primary)),
                  ),
                if (!monitor.enabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Disabled', style: TextStyle(color: theme.colorScheme.error)),
                  ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: monitors.length,
    );
  }
}

class _MonitorCanvas extends StatefulWidget {
  const _MonitorCanvas({required this.controller});

  final DisplayManagerController controller;

  @override
  State<_MonitorCanvas> createState() => _MonitorCanvasState();
}

class _MonitorCanvasState extends State<_MonitorCanvas> {
  String? _draggingId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final List<MonitorLayout> monitors = widget.controller.monitors;
        final MonitorLayout? selected = widget.controller.selectedMonitor;

        if (monitors.isEmpty) {
          return const Center(child: Text('No displays available.'));
        }

        final Rect bounds = widget.controller.computeBoundingBox(padding: 120);
        final double scale = _computeScale(bounds.size, constraints.biggest);
        final double scaledWidth = bounds.width * scale;
        final double scaledHeight = bounds.height * scale;
        final double offsetX = (constraints.maxWidth - scaledWidth) / 2;
        final double offsetY = (constraints.maxHeight - scaledHeight) / 2;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(),
                ),
              ),
              for (final MonitorLayout monitor in monitors)
                _buildMonitorTile(
                  context: context,
                  monitor: monitor,
                  selected: selected?.name == monitor.name,
                  offsetX: offsetX,
                  offsetY: offsetY,
                  bounds: bounds,
                  scale: scale,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonitorTile({
    required BuildContext context,
    required MonitorLayout monitor,
    required bool selected,
    required double offsetX,
    required double offsetY,
    required Rect bounds,
    required double scale,
  }) {
    final double left = offsetX + (monitor.x - bounds.left) * scale;
    final double top = offsetY + (monitor.y - bounds.top) * scale;
    final double width = monitor.width * scale;
    final double height = monitor.height * scale;

    final ThemeData theme = Theme.of(context);
    final bool isDragging = _draggingId == monitor.name;

    return Positioned(
      left: left,
      top: top,
      width: math.max(width, 40.0),
      height: math.max(height, 40.0),
      child: GestureDetector(
        onTap: () => widget.controller.selectMonitor(monitor.name),
        onPanStart: (_) {
          setState(() => _draggingId = monitor.name);
          widget.controller.selectMonitor(monitor.name);
        },
        onPanUpdate: (details) {
          final double deltaX = details.delta.dx / scale;
          final double deltaY = details.delta.dy / scale;
          final MonitorLayout current = widget.controller.monitors
              .firstWhere((item) => item.name == monitor.name, orElse: () => monitor);
          final double proposedX = current.x + deltaX;
          final double proposedY = current.y + deltaY;
          final Offset snapped = _applyEdgeSnapping(
            current: current,
            proposedX: proposedX,
            proposedY: proposedY,
            monitors: widget.controller.monitors,
          );
          final int newX = _snapToGrid(snapped.dx, step: 5);
          final int newY = _snapToGrid(snapped.dy, step: 5);
          widget.controller.setMonitorPosition(monitor.name, newX, newY);
        },
        onPanEnd: (_) {
          setState(() => _draggingId = null);
        },
        onPanCancel: () {
          setState(() => _draggingId = null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected || isDragging ? theme.colorScheme.primary : theme.dividerColor,
              width: selected || isDragging ? 2 : 1,
            ),
            color: monitor.enabled
                ? theme.colorScheme.primary.withOpacity(selected ? 0.25 : 0.18)
                : theme.disabledColor.withOpacity(0.3),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.45),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            monitor.description,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        if (monitor.isPrimary)
                          Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
                      ],
                    ),
                    Text(
                      '${monitor.width}×${monitor.height}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 8,
                left: 12,
                child: Text('Scale ${monitor.scale.toStringAsFixed(2)}x', style: theme.textTheme.bodySmall),
              ),
              if (monitor.isMirror)
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        monitor.mirrorSource ?? '-',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              if (!monitor.enabled)
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Text('Disabled', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _computeScale(Size contentSize, Size canvasSize) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return 1.0;
    }

    final double availableWidth = (canvasSize.width - 48).clamp(80, double.infinity);
    final double availableHeight = (canvasSize.height - 48).clamp(80, double.infinity);
    final double scaleX = availableWidth / contentSize.width;
    final double scaleY = availableHeight / contentSize.height;
    final double scale = scaleX.isFinite && scaleY.isFinite ? math.min(scaleX, scaleY) : 1.0;
    return scale.clamp(0.05, 3.0);
  }

  int _snapToGrid(double value, {required int step}) {
    if (step <= 1) {
      return value.round();
    }
    final double snapped = ((value / step).round() * step).toDouble();
    return snapped.round();
  }

  Offset _applyEdgeSnapping({
    required MonitorLayout current,
    required double proposedX,
    required double proposedY,
    required List<MonitorLayout> monitors,
    double threshold = 24,
  }) {
    double bestX = proposedX;
    double bestY = proposedY;
    double minXDelta = threshold + 1;
    double minYDelta = threshold + 1;

    final double left = proposedX;
    final double right = proposedX + current.width;
    final double top = proposedY;
    final double bottom = proposedY + current.height;

    void trySnapX(double targetEdge, double currentEdge, double candidateX) {
      final double delta = (currentEdge - targetEdge).abs();
      if (delta <= threshold && delta < minXDelta) {
        minXDelta = delta;
        bestX = candidateX;
      }
    }

    void trySnapY(double targetEdge, double currentEdge, double candidateY) {
      final double delta = (currentEdge - targetEdge).abs();
      if (delta <= threshold && delta < minYDelta) {
        minYDelta = delta;
        bestY = candidateY;
      }
    }

    // Snap to origin axes
    trySnapX(0, left, 0);
    trySnapX(0, right, -current.width.toDouble());
    trySnapY(0, top, 0);
    trySnapY(0, bottom, -current.height.toDouble());

    for (final MonitorLayout other in monitors) {
      if (identical(other, current) || other.name == current.name || !other.enabled) {
        continue;
      }

      final double otherLeft = other.x.toDouble();
      final double otherRight = (other.x + other.width).toDouble();
      final double otherTop = other.y.toDouble();
      final double otherBottom = (other.y + other.height).toDouble();

      // Horizontal snapping
      trySnapX(otherLeft, left, otherLeft);
      trySnapX(otherRight, left, otherRight);
      trySnapX(otherLeft, right, otherLeft - current.width);
      trySnapX(otherRight, right, otherRight - current.width);

      // Vertical snapping
      trySnapY(otherTop, top, otherTop);
      trySnapY(otherBottom, top, otherBottom);
      trySnapY(otherTop, bottom, otherTop - current.height);
      trySnapY(otherBottom, bottom, otherBottom - current.height);
    }

    return Offset(bestX, bestY);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 40;
    final Paint paint = Paint()
      ..color = const Color(0x11000000)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonitorDetailsPanel extends StatefulWidget {
  const _MonitorDetailsPanel({required this.controller});

  final DisplayManagerController controller;

  @override
  State<_MonitorDetailsPanel> createState() => _MonitorDetailsPanelState();
}

class _MonitorDetailsPanelState extends State<_MonitorDetailsPanel> {
  late TextEditingController _xController;
  late TextEditingController _yController;

  @override
  void initState() {
    super.initState();
    _xController = TextEditingController();
    _yController = TextEditingController();
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitor = widget.controller.selectedMonitor;
    if (monitor == null) {
      return const Card(
        child: Center(child: Text('Select a monitor to edit settings.')),
      );
    }

    _xController.value = TextEditingValue(text: monitor.x.toString());
    _yController.value = TextEditingValue(text: monitor.y.toString());

    final List<MonitorLayout> otherMonitors = widget.controller.monitors
        .where((item) => item.name != monitor.name && !item.isMirror)
        .toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(monitor.description, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: monitor.enabled,
              onChanged: (value) {
                if (value != null) {
                  widget.controller.setMonitorEnabled(monitor.name, value);
                }
              },
              title: const Text('Enabled'),
            ),
            CheckboxListTile(
              value: monitor.isPrimary,
              onChanged: (value) {
                if (value == true) {
                  widget.controller.setPrimary(monitor.name);
                }
              },
              title: const Text('Primary display'),
            ),
            const Divider(),
            Text('Position', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _xController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'X offset'),
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        widget.controller.setMonitorPosition(monitor.name, parsed, monitor.y);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _yController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Y offset'),
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        widget.controller.setMonitorPosition(monitor.name, monitor.x, parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Scale', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: monitor.scale.clamp(0.5, 4.0),
              min: 0.5,
              max: 4,
              divisions: 35,
              label: '${monitor.scale.toStringAsFixed(2)}x',
              onChanged: (value) => widget.controller.setMonitorScale(monitor.name, value),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: monitor.isMirror,
              onChanged: (value) {
                final String? source = (value && monitor.mirrorSource == null && otherMonitors.isNotEmpty)
                    ? otherMonitors.first.name
                    : monitor.mirrorSource;
                widget.controller.setMirror(monitor.name, enabled: value, source: source);
              },
              title: const Text('Mirror this display'),
              subtitle: monitor.isMirror && monitor.mirrorSource != null
                  ? Text('Source: ${monitor.mirrorSource}')
                  : null,
            ),
            if (monitor.isMirror)
              DropdownButtonFormField<String>(
                value: monitor.mirrorSource,
                items: otherMonitors
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.name,
                        child: Text(item.description),
                      ),
                    )
                    .toList(),
                onChanged: (value) => widget.controller.setMirror(monitor.name, enabled: true, source: value),
                decoration: const InputDecoration(labelText: 'Mirror source'),
              ),
          ],
        ),
      ),
    );
  }
}

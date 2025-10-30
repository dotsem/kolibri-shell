import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/display_config.dart';
import '../services/display_service.dart';
import '../services/config_service.dart';

class DisplayCanvasScreen extends StatefulWidget {
  const DisplayCanvasScreen({super.key});

  @override
  State<DisplayCanvasScreen> createState() => _DisplayCanvasScreenState();
}

class _DisplayCanvasScreenState extends State<DisplayCanvasScreen> {
  List<Monitor> _monitors = [];
  Map<String, MonitorConfig> _configs = {};
  Map<String, MonitorConfig>? _previousConfigs; // For reverting
  Map<String, MonitorConfig>? _lastAppliedConfigs; // Last successfully applied config
  String? _selectedMonitorName;
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _error;

  // Canvas viewport
  double _scale = 0.15; // Zoom level
  Offset _panOffset = Offset.zero;

  // Confirmation countdown
  bool _awaitingConfirmation = false;
  int _countdownSeconds = 15;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadMonitors();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMonitors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isAvailable = await DisplayService.instance.isHyprlandAvailable();
      if (!isAvailable) {
        setState(() {
          _error = 'Hyprland is not running or hyprctl is not available';
          _isLoading = false;
        });
        return;
      }

      final monitors = await DisplayService.instance.getMonitors();
      if (monitors.isEmpty) {
        setState(() {
          _error = 'No monitors detected';
          _isLoading = false;
        });
        return;
      }

      // Load saved config or use current state
      final savedConfig = await ConfigService.instance.readDisplayConfig();
      final configs = <String, MonitorConfig>{};
      String? primary;

      for (final monitor in monitors) {
        MonitorConfig? saved;
        if (savedConfig != null) {
          final savedMonitors = DisplayConfig.fromJson(savedConfig).monitors;
          saved = savedMonitors.where((m) => m.name == monitor.name).firstOrNull;
        }

        configs[monitor.name] = saved ?? monitor.toMonitorConfig();

        if (configs[monitor.name]!.isPrimary) {
          primary = monitor.name;
        }
      }

      // If no primary is set, use the focused monitor
      if (primary == null && monitors.isNotEmpty) {
        final focused = monitors.where((m) => m.focused).firstOrNull;
        primary = focused?.name ?? monitors.first.name;
        configs[primary] = configs[primary]!.copyWith(isPrimary: true);
      }

      setState(() {
        _monitors = monitors;
        _configs = configs;
        _lastAppliedConfigs = Map.from(configs); // Save as last applied
        _isLoading = false;
        _hasChanges = false;
        // Select the first monitor by default
        if (_selectedMonitorName == null && monitors.isNotEmpty) {
          _selectedMonitorName = monitors.first.name;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading monitors: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndApply() async {
    try {
      // Save LAST APPLIED configs for reverting (not current _configs!)
      // _configs has the NEW values, _lastAppliedConfigs has the OLD values
      _previousConfigs = _lastAppliedConfigs != null ? Map.from(_lastAppliedConfigs!) : Map.from(_configs);

      print('[DisplayCanvas] Saving previous configs for revert: ${_previousConfigs!.keys}');
      for (final entry in _previousConfigs!.entries) {
        print('[DisplayCanvas]   ${entry.key}: pos=${entry.value.position.x},${entry.value.position.y} scale=${entry.value.scale}');
      }

      final displayConfig = DisplayConfig(monitors: _configs.values.toList());

      print('[DisplayCanvas] Applying new configuration...');
      for (final monitor in displayConfig.monitors) {
        print('[DisplayCanvas]   ${monitor.name}: pos=${monitor.position.x},${monitor.position.y} scale=${monitor.scale}');
      }

      // Apply to Hyprland first
      final applied = await DisplayService.instance.applyDisplayConfig(displayConfig);
      if (!applied) {
        print('[DisplayCanvas] Failed to apply configuration');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply configuration')));
        }
        _previousConfigs = null;
        return;
      }

      print('[DisplayCanvas] Configuration applied successfully, starting countdown');
      // Start confirmation countdown
      setState(() {
        _awaitingConfirmation = true;
        _countdownSeconds = 15;
      });

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _countdownSeconds--;
        });

        if (_countdownSeconds <= 0) {
          timer.cancel();
          print('[DisplayCanvas] Countdown reached 0, reverting...');
          _revertChanges();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration applied! Confirm to keep changes.'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      print('[DisplayCanvas] Error in _saveAndApply: $e');
      _previousConfigs = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmChanges() async {
    _countdownTimer?.cancel();

    setState(() {
      _awaitingConfirmation = false;
    });

    final displayConfig = DisplayConfig(monitors: _configs.values.toList());

    // Save to JSON
    final saved = await ConfigService.instance.writeDisplayConfig(displayConfig.toJson());
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save configuration')));
      }
      return;
    }

    // Generate shell script for Hyprland startup
    await _generateHyprlandScript(displayConfig);

    // Update last applied configs to current (confirmed) configs
    _lastAppliedConfigs = Map.from(_configs);
    print('[DisplayCanvas] Updated last applied configs after confirmation');

    setState(() {
      _hasChanges = false;
    });

    _previousConfigs = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display configuration saved successfully!')));
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await _loadMonitors();
  }

  Future<void> _revertChanges() async {
    print('[DisplayCanvas] _revertChanges called');
    _countdownTimer?.cancel();

    if (_previousConfigs == null) {
      print('[DisplayCanvas] No previous configs to revert to');
      setState(() {
        _awaitingConfirmation = false;
      });
      return;
    }

    print('[DisplayCanvas] Reverting to previous configs: ${_previousConfigs!.keys}');
    final displayConfig = DisplayConfig(monitors: _previousConfigs!.values.toList());

    // Debug: Print what we're reverting to
    for (final monitor in displayConfig.monitors) {
      print('[DisplayCanvas] Reverting ${monitor.name} to position ${monitor.position.x},${monitor.position.y}');
    }

    // Revert in Hyprland - THIS IS THE KEY PART
    print('[DisplayCanvas] Calling DisplayService.applyDisplayConfig...');
    final reverted = await DisplayService.instance.applyDisplayConfig(displayConfig);
    print('[DisplayCanvas] Revert result: $reverted');

    if (!reverted) {
      print('[DisplayCanvas] Failed to revert!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to revert changes - please check hyprctl'), backgroundColor: Colors.red));
      }
      setState(() {
        _awaitingConfirmation = false;
      });
      return;
    }

    print('[DisplayCanvas] Revert successful, updating UI state');
    // Update UI state
    setState(() {
      _configs = Map.from(_previousConfigs!);
      _awaitingConfirmation = false;
      _hasChanges = false;
    });

    _previousConfigs = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes reverted successfully'), backgroundColor: Colors.orange));
    }

    // Reload monitors to verify the revert worked
    print('[DisplayCanvas] Reloading monitors...');
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadMonitors();
    print('[DisplayCanvas] Revert complete');
  }

  Future<void> _generateHyprlandScript(DisplayConfig config) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('#!/bin/sh');
      buffer.writeln('# Auto-generated display configuration for Hyprland');
      buffer.writeln('# Generated by Kolibri Settings');
      buffer.writeln('');

      for (final monitor in config.monitors) {
        if (!monitor.enabled) {
          buffer.writeln('hyprctl keyword monitor ${monitor.name},disable');
          continue;
        }

        final resolution = '${monitor.resolution.width}x${monitor.resolution.height}';
        final rate = monitor.refreshRate.toStringAsFixed(2);
        final position = '${monitor.position.x}x${monitor.position.y}';
        final scale = monitor.scale.toStringAsFixed(2);
        final transform = (monitor.rotation ~/ 90);

        var command = '${monitor.name},$resolution@$rate,$position,$scale';

        if (transform != 0) {
          command += ',transform,$transform';
        }

        if (monitor.mirror != null) {
          command += ',mirror,${monitor.mirror}';
        }

        buffer.writeln('hyprctl keyword monitor $command');
      }

      final scriptPath = '${Platform.environment['HOME']}/.config/hypr_flutter/apply_displays.sh';
      final file = File(scriptPath);
      await file.writeAsString(buffer.toString());

      // Make executable
      await Process.run('chmod', ['+x', scriptPath]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Startup script saved to:\n$scriptPath'), duration: const Duration(seconds: 3)));
      }
    } catch (e) {
      print('Error generating Hyprland script: $e');
    }
  }

  void _updateMonitorPosition(String monitorName, Offset position, {bool snap = false}) {
    final config = _configs[monitorName]!;
    int x = position.dx.round();
    int y = position.dy.round();

    if (snap) {
      const snapDistance = 50;
      bool snappedX = false;
      bool snappedY = false;

      // Priority 1: Snap to origin (0,0)
      if (x.abs() < snapDistance && y.abs() < snapDistance) {
        x = 0;
        y = 0;
        snappedX = true;
        snappedY = true;
      } else {
        // Priority 2: Snap to other monitors' edges
        final thisWidth = config.resolution.width;
        final thisHeight = config.resolution.height;

        // Find closest snap point for X and Y independently
        int? bestSnapX;
        int? bestSnapY;
        double bestDistanceX = snapDistance.toDouble();
        double bestDistanceY = snapDistance.toDouble();

        for (final other in _configs.entries) {
          if (other.key == monitorName) continue;
          final otherConfig = other.value;
          if (!otherConfig.enabled) continue;

          final otherX = otherConfig.position.x;
          final otherY = otherConfig.position.y;
          final otherRight = otherX + otherConfig.resolution.width;
          final otherBottom = otherY + otherConfig.resolution.height;

          // Try all possible X snap positions
          final snapPositionsX = [
            otherRight, // Left edge to other's right edge
            otherX - thisWidth, // Right edge to other's left edge
            otherX, // Left edges aligned
            otherRight - thisWidth, // Right edges aligned
          ];

          for (final snapX in snapPositionsX) {
            final distance = (x - snapX).abs().toDouble();
            if (distance < bestDistanceX) {
              // Check if at this X position, monitors would overlap vertically
              final thisBottom = y + thisHeight;
              bool wouldOverlapY = !(thisBottom <= otherY || y >= otherBottom);

              if (wouldOverlapY) {
                bestDistanceX = distance;
                bestSnapX = snapX;
              }
            }
          }

          // Try all possible Y snap positions
          final snapPositionsY = [
            otherBottom, // Top edge to other's bottom edge
            otherY - thisHeight, // Bottom edge to other's top edge
            otherY, // Top edges aligned
            otherBottom - thisHeight, // Bottom edges aligned
          ];

          for (final snapY in snapPositionsY) {
            final distance = (y - snapY).abs().toDouble();
            if (distance < bestDistanceY) {
              // Check if at this Y position, monitors would overlap horizontally
              final thisRight = x + thisWidth;
              bool wouldOverlapX = !(thisRight <= otherX || x >= otherRight);

              if (wouldOverlapX) {
                bestDistanceY = distance;
                bestSnapY = snapY;
              }
            }
          }
        }

        if (bestSnapX != null) {
          x = bestSnapX;
          snappedX = true;
        }
        if (bestSnapY != null) {
          y = bestSnapY;
          snappedY = true;
        }

        // Priority 3: Snap to grid (only if not snapped to edges)
        const snapGrid = 250;
        if (!snappedX) {
          x = (x / snapGrid).round() * snapGrid;
        }
        if (!snappedY) {
          y = (y / snapGrid).round() * snapGrid;
        }
      }
    }

    setState(() {
      _configs[monitorName] = config.copyWith(position: Position(x, y));
      _hasChanges = true;
    });
  }

  void _updateMonitorConfig(String monitorName, MonitorConfig config) {
    setState(() {
      _configs[monitorName] = config;
      _hasChanges = true;
    });
  }

  void _setPrimaryMonitor(String monitorName) {
    setState(() {
      // Remove primary from all monitors
      _configs = _configs.map((name, config) {
        return MapEntry(name, config.copyWith(isPrimary: false));
      });

      // Set the selected monitor as primary
      _configs[monitorName] = _configs[monitorName]!.copyWith(isPrimary: true);
      _hasChanges = true;
    });
  }

  bool _canDisableMonitor(String monitorName) {
    // Can't disable if it's the only enabled monitor
    final enabledCount = _configs.values.where((c) => c.enabled).length;
    return enabledCount > 1;
  }

  bool _canDisablePrimary(String monitorName) {
    final config = _configs[monitorName]!;
    // Can't disable the primary monitor
    return !config.isPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Arrangement'),
        actions: [
          if (_awaitingConfirmation) ...[
            // Show minimal info in AppBar during confirmation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text('Awaiting confirmation...', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.orange)),
              ),
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadMonitors, tooltip: 'Refresh monitors'),
            if (_hasChanges) ...[
              const SizedBox(width: 8),
              TextButton.icon(icon: const Icon(Icons.undo), label: const Text('Reset'), onPressed: _loadMonitors),
              const SizedBox(width: 8),
              FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Apply'), onPressed: _saveAndApply),
              const SizedBox(width: 16),
            ],
          ],
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          // Confirmation modal overlay
          if (_awaitingConfirmation) _buildConfirmationOverlay(),
        ],
      ),
    );
  }

  Widget _buildConfirmationOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Keep this configuration?', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  'Reverting in $_countdownSeconds seconds',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _countdownSeconds / 15, backgroundColor: Colors.grey[300], valueColor: AlwaysStoppedAnimation<Color>(_countdownSeconds > 5 ? Colors.orange : Colors.red)),
                const SizedBox(height: 24),
                const Text('If you can see this message and your displays look correct, click "Keep Changes" to confirm.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Revert Now'),
                        onPressed: _revertChanges,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Keep Changes'),
                        onPressed: _confirmChanges,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Detecting monitors...')]),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _loadMonitors),
          ],
        ),
      );
    }

    if (_monitors.isEmpty) {
      return const Center(child: Text('No monitors detected'));
    }

    // Use LayoutBuilder to make responsive
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 1000;

        if (isWideScreen) {
          // Side-by-side layout for wide screens
          return Row(
            children: [
              // Canvas area
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(child: _buildCanvas()),
                    // Monitor info at bottom
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
                      ),
                      child: _buildMonitorInfo(),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Settings panel
              SizedBox(width: 400, child: _buildSettingsPanel()),
            ],
          );
        } else {
          // Stacked layout for narrow screens
          return Column(
            children: [
              // Canvas area
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(child: _buildCanvas()),
                    // Monitor info at bottom
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
                      ),
                      child: _buildMonitorInfo(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Settings panel below
              Expanded(flex: 1, child: _buildSettingsPanel()),
            ],
          );
        }
      },
    );
  }

  Widget _buildMonitorInfo() {
    if (_selectedMonitorName == null) {
      return const Center(child: Text('No monitor selected'));
    }

    final monitor = _monitors.where((m) => m.name == _selectedMonitorName).firstOrNull;
    if (monitor == null) return const SizedBox.shrink();

    final config = _configs[monitor.name]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      children: [
        _buildInfoChip(Icons.monitor, monitor.name),
        const SizedBox(width: 8),
        _buildInfoChip(Icons.aspect_ratio, config.resolution.toString()),
        const SizedBox(width: 8),
        _buildInfoChip(Icons.refresh, '${config.refreshRate.toStringAsFixed(0)} Hz'),
        const SizedBox(width: 8),
        _buildInfoChip(Icons.zoom_in, '${config.scale.toStringAsFixed(2)}x'),
        const SizedBox(width: 8),
        _buildInfoChip(Icons.location_on, '${config.position.x}, ${config.position.y}'),
        if (config.rotation != 0) ...[const SizedBox(width: 8), _buildInfoChip(Icons.rotate_right, '${config.rotation}°')],
        if (config.isPrimary) ...[const SizedBox(width: 8), _buildInfoChip(Icons.star, 'Primary', isPrimary: true)],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {bool isPrimary = false}) {
    return Chip(
      avatar: Icon(icon, size: 18, color: isPrimary ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
      label: Text(label),
      backgroundColor: isPrimary ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: isPrimary ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildCanvas() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Scroll to zoom
                setState(() {
                  if (event.scrollDelta.dy < 0) {
                    _scale = (_scale * 1.1).clamp(0.05, 0.5);
                  } else {
                    _scale = (_scale / 1.1).clamp(0.05, 0.5);
                  }
                });
              }
            },
            child: GestureDetector(
              // Middle-click or right-click to pan
              onPanStart: (details) {
                // Store initial pan offset
              },
              onPanUpdate: (details) {
                setState(() {
                  final newPanOffset = _panOffset + details.delta;
                  // Constrain pan to reasonable bounds (±2000px from center)
                  _panOffset = Offset(newPanOffset.dx.clamp(-2000.0, 2000.0), newPanOffset.dy.clamp(-2000.0, 2000.0));
                });
              },
              child: Stack(
                children: [
                  // Grid background
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: GridPainter(scale: _scale, panOffset: _panOffset, color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
                  ),
                  // Monitor representations
                  ..._monitors.map((monitor) {
                    final config = _configs[monitor.name]!;
                    if (!config.enabled) return const SizedBox.shrink();

                    return _MonitorWidget(
                      monitor: monitor,
                      config: config,
                      scale: _scale,
                      panOffset: _panOffset,
                      canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                      isSelected: _selectedMonitorName == monitor.name,
                      onTap: () {
                        setState(() {
                          _selectedMonitorName = monitor.name;
                        });
                      },
                      onPositionChanged: (newPos) {
                        _updateMonitorPosition(monitor.name, newPos);
                      },
                      onPositionChangeEnd: (newPos) {
                        _updateMonitorPosition(monitor.name, newPos, snap: true);
                      },
                    );
                  }),
                  // Zoom controls
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Card(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _scale = (_scale * 1.2).clamp(0.05, 0.5);
                              });
                            },
                            tooltip: 'Zoom in',
                          ),
                          Text('${(_scale * 100).round()}%'),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                _scale = (_scale / 1.2).clamp(0.05, 0.5);
                              });
                            },
                            tooltip: 'Zoom out',
                          ),
                          const Divider(height: 1),
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong),
                            onPressed: () {
                              setState(() {
                                _scale = 0.15;
                                _panOffset = Offset.zero;
                              });
                            },
                            tooltip: 'Reset view',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsPanel() {
    if (_selectedMonitorName == null) {
      return const Center(child: Text('Select a monitor to configure'));
    }

    final monitor = _monitors.where((m) => m.name == _selectedMonitorName).firstOrNull;
    if (monitor == null) {
      return const Center(child: Text('Monitor not found'));
    }

    final config = _configs[monitor.name]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonitorHeader(monitor, config),
        const SizedBox(height: 16),
        _buildResolutionSelector(monitor, config),
        const SizedBox(height: 16),
        _buildRefreshRateSelector(monitor, config),
        const SizedBox(height: 16),
        _buildPositionDisplay(config),
        const SizedBox(height: 16),
        _buildScaleControl(monitor, config),
        const SizedBox(height: 16),
        _buildRotationSelector(monitor, config),
        const SizedBox(height: 16),
        _buildMirrorSelector(monitor, config),
        const SizedBox(height: 16),
        _buildMonitorToggles(monitor, config),
      ],
    );
  }

  Widget _buildMonitorHeader(Monitor monitor, MonitorConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monitor, size: 32, color: config.isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monitor.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (monitor.description.isNotEmpty) Text(monitor.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
          ],
        ),
        if (config.isPrimary) ...[
          const SizedBox(height: 8),
          Chip(
            label: const Text('Primary Display'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ],
      ],
    );
  }

  Widget _buildResolutionSelector(Monitor monitor, MonitorConfig config) {
    final resolutions = monitor.availableResolutions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolution', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<Resolution>(
          value: config.resolution,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: resolutions.map((res) {
            return DropdownMenuItem(value: res, child: Text(res.toString()));
          }).toList(),
          onChanged: config.enabled
              ? (value) {
                  if (value != null) {
                    final rates = monitor.getRefreshRatesForResolution(value);
                    final newRate = rates.contains(config.refreshRate) ? config.refreshRate : rates.first;

                    _updateMonitorConfig(monitor.name, config.copyWith(resolution: value, refreshRate: newRate));
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildRefreshRateSelector(Monitor monitor, MonitorConfig config) {
    final refreshRates = monitor.getRefreshRatesForResolution(config.resolution);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Refresh Rate', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<double>(
          value: refreshRates.contains(config.refreshRate) ? config.refreshRate : refreshRates.first,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: refreshRates.map((rate) {
            return DropdownMenuItem(value: rate, child: Text('${rate.toStringAsFixed(2)} Hz'));
          }).toList(),
          onChanged: config.enabled
              ? (value) {
                  if (value != null) {
                    _updateMonitorConfig(monitor.name, config.copyWith(refreshRate: value));
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPositionDisplay(MonitorConfig config) {
    // Create controllers with current values
    final xController = TextEditingController(text: config.position.x.toString());
    final yController = TextEditingController(text: config.position.y.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Position', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: xController,
                decoration: const InputDecoration(labelText: 'X', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                onFieldSubmitted: (value) {
                  final x = int.tryParse(value) ?? 0;
                  _updateMonitorConfig(_selectedMonitorName!, config.copyWith(position: Position(x, config.position.y)));
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: yController,
                decoration: const InputDecoration(labelText: 'Y', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                onFieldSubmitted: (value) {
                  final y = int.tryParse(value) ?? 0;
                  _updateMonitorConfig(_selectedMonitorName!, config.copyWith(position: Position(config.position.x, y)));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Drag the monitor on the canvas to reposition', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildScaleControl(Monitor monitor, MonitorConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scale', style: Theme.of(context).textTheme.titleSmall),
            Text('${config.scale.toStringAsFixed(2)}x', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: config.scale,
          min: 0.5,
          max: 3.0,
          divisions: 25,
          label: '${config.scale.toStringAsFixed(2)}x',
          onChanged: config.enabled
              ? (value) {
                  _updateMonitorConfig(monitor.name, config.copyWith(scale: value));
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildRotationSelector(Monitor monitor, MonitorConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rotation', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: config.rotation,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 0, child: Text('0° (Normal)')),
            DropdownMenuItem(value: 90, child: Text('90° (Right)')),
            DropdownMenuItem(value: 180, child: Text('180° (Inverted)')),
            DropdownMenuItem(value: 270, child: Text('270° (Left)')),
          ],
          onChanged: config.enabled
              ? (value) {
                  if (value != null) {
                    _updateMonitorConfig(monitor.name, config.copyWith(rotation: value));
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildMirrorSelector(Monitor monitor, MonitorConfig config) {
    // Get list of other monitors that can be mirrored
    // Exclude monitors that are already mirroring this one (prevent circular references)
    final otherMonitors = _monitors.where((m) {
      if (m.name == monitor.name) return false;
      final otherConfig = _configs[m.name];
      if (otherConfig == null || !otherConfig.enabled) return false;
      // Don't allow mirroring a monitor that's mirroring this one
      if (otherConfig.mirror == monitor.name) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mirror Display', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: config.mirror,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'No mirroring'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None (Independent display)')),
            ...otherMonitors.map((m) {
              return DropdownMenuItem<String?>(value: m.name, child: Text('Mirror ${m.name}'));
            }),
          ],
          onChanged: config.enabled && otherMonitors.isNotEmpty
              ? (value) {
                  // Clear mirror from any monitor that was mirroring this one
                  if (value != null) {
                    final Map<String, MonitorConfig> updatedConfigs = {};
                    for (final entry in _configs.entries) {
                      if (entry.value.mirror == monitor.name) {
                        updatedConfigs[entry.key] = entry.value.copyWith(mirror: () => null);
                      }
                    }
                    if (updatedConfigs.isNotEmpty) {
                      setState(() {
                        _configs.addAll(updatedConfigs);
                      });
                    }
                  }

                  _updateMonitorConfig(monitor.name, config.copyWith(mirror: () => value));
                }
              : null,
        ),
        if (config.mirror != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.flip_to_front, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('This display will show the same content as ${config.mirror}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                ),
              ],
            ),
          ),
        ],
        if (otherMonitors.isEmpty && config.mirror == null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('No other monitors available to mirror', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonitorToggles(Monitor monitor, MonitorConfig config) {
    final canDisable = _canDisableMonitor(monitor.name);
    final canDisablePrimary = _canDisablePrimary(monitor.name);

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enabled'),
          subtitle: Text(
            canDisable
                ? 'Enable or disable this monitor'
                : canDisablePrimary
                ? 'Cannot disable the only monitor'
                : 'Cannot disable the primary monitor',
          ),
          value: config.enabled,
          onChanged: (canDisable && canDisablePrimary)
              ? (value) {
                  _updateMonitorConfig(monitor.name, config.copyWith(enabled: value));
                }
              : null,
        ),
        if (_monitors.length > 1)
          SwitchListTile(
            title: const Text('Primary Monitor'),
            subtitle: const Text('Set as the primary display'),
            value: config.isPrimary,
            onChanged: config.enabled
                ? (value) {
                    if (value) {
                      _setPrimaryMonitor(monitor.name);
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

class _MonitorWidget extends StatefulWidget {
  final Monitor monitor;
  final MonitorConfig config;
  final double scale;
  final Offset panOffset;
  final Size canvasSize;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Offset) onPositionChanged;
  final Function(Offset) onPositionChangeEnd;

  const _MonitorWidget({
    required this.monitor,
    required this.config,
    required this.scale,
    required this.panOffset,
    required this.canvasSize,
    required this.isSelected,
    required this.onTap,
    required this.onPositionChanged,
    required this.onPositionChangeEnd,
  });

  @override
  State<_MonitorWidget> createState() => _MonitorWidgetState();
}

class _MonitorWidgetState extends State<_MonitorWidget> {
  Offset? _dragStartPosition;

  @override
  Widget build(BuildContext context) {
    // Calculate position on canvas
    final centerX = widget.canvasSize.width / 2;
    final centerY = widget.canvasSize.height / 2;

    final screenX = centerX + (widget.config.position.x * widget.scale) + widget.panOffset.dx;
    final screenY = centerY + (widget.config.position.y * widget.scale) + widget.panOffset.dy;

    final width = widget.config.resolution.width * widget.scale;
    final height = widget.config.resolution.height * widget.scale;

    return Positioned(
      left: screenX,
      top: screenY,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (details) {
          _dragStartPosition = Offset(widget.config.position.x.toDouble(), widget.config.position.y.toDouble());
        },
        onPanUpdate: (details) {
          if (_dragStartPosition != null) {
            final newX = _dragStartPosition!.dx + (details.localPosition.dx / widget.scale - widget.config.resolution.width / 2);
            final newY = _dragStartPosition!.dy + (details.localPosition.dy / widget.scale - widget.config.resolution.height / 2);
            widget.onPositionChanged(Offset(newX, newY));
          }
        },
        onPanEnd: (details) {
          if (_dragStartPosition != null) {
            final newX = _dragStartPosition!.dx + (details.localPosition.dx / widget.scale - widget.config.resolution.width / 2);
            final newY = _dragStartPosition!.dy + (details.localPosition.dy / widget.scale - widget.config.resolution.height / 2);
            widget.onPositionChangeEnd(Offset(newX, newY));
          }
          _dragStartPosition = null;
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: widget.config.isPrimary ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainer,
            border: Border.all(color: widget.isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline, width: widget.isSelected ? 3 : 1),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              // Monitor info
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor, size: 32 * widget.scale * 4, color: widget.config.isPrimary ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      widget.monitor.name,
                      style: TextStyle(fontSize: 12 * widget.scale * 4, fontWeight: FontWeight.bold, color: widget.config.isPrimary ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      widget.config.resolution.toString(),
                      style: TextStyle(fontSize: 10 * widget.scale * 4, color: widget.config.isPrimary ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Primary badge
              if (widget.config.isPrimary)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'PRIMARY',
                      style: TextStyle(fontSize: 10 * widget.scale * 4, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ),
              // Mirror badge
              if (widget.config.mirror != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiary, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flip_to_front, size: 12 * widget.scale * 4, color: Theme.of(context).colorScheme.onTertiary),
                        SizedBox(width: 4 * widget.scale * 4),
                        Text(
                          'MIRROR',
                          style: TextStyle(fontSize: 10 * widget.scale * 4, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final double scale;
  final Offset panOffset;
  final Color color;

  GridPainter({required this.scale, required this.panOffset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final gridSize = 100 * scale; // 100 pixels grid
    final centerX = size.width / 2 + panOffset.dx;
    final centerY = size.height / 2 + panOffset.dy;

    // Draw vertical lines
    for (double x = centerX % gridSize; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = centerY % gridSize; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw origin lines (thicker)
    final originPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), originPaint);
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), originPaint);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return scale != oldDelegate.scale || panOffset != oldDelegate.panOffset;
  }
}

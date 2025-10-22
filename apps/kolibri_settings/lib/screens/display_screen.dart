import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/display_config.dart';
import '../services/display_service.dart';
import '../services/config_service.dart';

class DisplayScreen extends StatefulWidget {
  const DisplayScreen({super.key});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  List<Monitor> _monitors = [];
  Map<String, MonitorConfig> _configs = {};
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonitors();
  }

  Future<void> _loadMonitors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if Hyprland is available
      final isAvailable = await DisplayService.instance.isHyprlandAvailable();
      if (!isAvailable) {
        setState(() {
          _error = 'Hyprland is not running or hyprctl is not available';
          _isLoading = false;
        });
        return;
      }

      // Get current monitors
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
        // Try to find saved config for this monitor
        MonitorConfig? saved;
        if (savedConfig != null) {
          final savedMonitors = DisplayConfig.fromJson(savedConfig).monitors;
          saved = savedMonitors.where((m) => m.name == monitor.name).firstOrNull;
        }

        // Use saved config or create from current state
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
        _isLoading = false;
        _hasChanges = false;
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
      // Create display config
      final displayConfig = DisplayConfig(monitors: _configs.values.toList());

      // Save to file
      final saved = await ConfigService.instance.writeDisplayConfig(displayConfig.toJson());
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save configuration')));
        }
        return;
      }

      // Apply to Hyprland
      final applied = await DisplayService.instance.applyDisplayConfig(displayConfig);
      if (!applied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved but failed to apply')));
        }
        return;
      }

      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display configuration applied successfully!')));
      }

      // Reload monitors to show updated state
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadMonitors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _resetChanges() {
    _loadMonitors();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Settings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadMonitors, tooltip: 'Refresh monitors'),
          if (_hasChanges) ...[
            const SizedBox(width: 8),
            TextButton.icon(icon: const Icon(Icons.undo), label: const Text('Reset'), onPressed: _resetChanges),
            const SizedBox(width: 8),
            FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Apply'), onPressed: _saveAndApply),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _buildBody(),
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

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _monitors.length,
      itemBuilder: (context, index) {
        final monitor = _monitors[index];
        final config = _configs[monitor.name]!;
        return Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildMonitorCard(monitor, config));
      },
    );
  }

  Widget _buildMonitorCard(Monitor monitor, MonitorConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonitorHeader(monitor, config),
            const Divider(height: 24),
            if (config.enabled) ...[
              _buildResolutionSelector(monitor, config),
              const SizedBox(height: 16),
              _buildRefreshRateSelector(monitor, config),
              const SizedBox(height: 16),
              _buildPositionControls(monitor, config),
              const SizedBox(height: 16),
              _buildScaleControl(monitor, config),
              const SizedBox(height: 16),
            ],
            _buildMonitorToggles(monitor, config),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorHeader(Monitor monitor, MonitorConfig config) {
    return Row(
      children: [
        Icon(Icons.monitor, size: 32, color: config.isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(monitor.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (config.isPrimary) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Primary'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              if (monitor.description.isNotEmpty) Text(monitor.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResolutionSelector(Monitor monitor, MonitorConfig config) {
    final resolutions = monitor.availableResolutions;

    return Row(
      children: [
        SizedBox(width: 120, child: Text('Resolution', style: Theme.of(context).textTheme.bodyLarge)),
        Expanded(
          child: DropdownButton<Resolution>(
            value: config.resolution,
            isExpanded: true,
            items: resolutions.map((res) {
              return DropdownMenuItem(value: res, child: Text(res.toString()));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                // Get available refresh rates for this resolution
                final rates = monitor.getRefreshRatesForResolution(value);
                final newRate = rates.contains(config.refreshRate) ? config.refreshRate : rates.first;

                _updateMonitorConfig(monitor.name, config.copyWith(resolution: value, refreshRate: newRate));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshRateSelector(Monitor monitor, MonitorConfig config) {
    final refreshRates = monitor.getRefreshRatesForResolution(config.resolution);

    return Row(
      children: [
        SizedBox(width: 120, child: Text('Refresh Rate', style: Theme.of(context).textTheme.bodyLarge)),
        Expanded(
          child: DropdownButton<double>(
            value: refreshRates.contains(config.refreshRate) ? config.refreshRate : refreshRates.first,
            isExpanded: true,
            items: refreshRates.map((rate) {
              return DropdownMenuItem(value: rate, child: Text('${rate.toStringAsFixed(2)} Hz'));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateMonitorConfig(monitor.name, config.copyWith(refreshRate: value));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPositionControls(Monitor monitor, MonitorConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Position', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'X', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: TextEditingController(text: config.position.x.toString()),
                onSubmitted: (value) {
                  final x = int.tryParse(value) ?? 0;
                  _updateMonitorConfig(monitor.name, config.copyWith(position: Position(x, config.position.y)));
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Y', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: TextEditingController(text: config.position.y.toString()),
                onSubmitted: (value) {
                  final y = int.tryParse(value) ?? 0;
                  _updateMonitorConfig(monitor.name, config.copyWith(position: Position(config.position.x, y)));
                },
              ),
            ),
          ],
        ),
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
            Text('Scale', style: Theme.of(context).textTheme.bodyLarge),
            Text('${config.scale.toStringAsFixed(2)}x', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: config.scale,
          min: 0.5,
          max: 3.0,
          divisions: 25,
          label: '${config.scale.toStringAsFixed(2)}x',
          onChanged: (value) {
            _updateMonitorConfig(monitor.name, config.copyWith(scale: value));
          },
        ),
      ],
    );
  }

  Widget _buildMonitorToggles(Monitor monitor, MonitorConfig config) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enabled'),
          subtitle: const Text('Enable or disable this monitor'),
          value: config.enabled,
          onChanged: (value) {
            _updateMonitorConfig(monitor.name, config.copyWith(enabled: value));
          },
        ),
        if (_monitors.length > 1)
          SwitchListTile(
            title: const Text('Primary Monitor'),
            subtitle: const Text('Set as the primary display'),
            value: config.isPrimary,
            onChanged: (value) {
              if (value) {
                _setPrimaryMonitor(monitor.name);
              }
            },
          ),
      ],
    );
  }
}

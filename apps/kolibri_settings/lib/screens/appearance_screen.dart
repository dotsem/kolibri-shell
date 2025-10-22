import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/appearance_config.dart';
import '../services/config_service.dart';

class AppearanceScreen extends StatefulWidget {
  final AppearanceConfig config;
  final Function(AppearanceConfig) onConfigChanged;

  const AppearanceScreen({super.key, required this.config, required this.onConfigChanged});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late AppearanceConfig _config;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  void didUpdateWidget(AppearanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config) {
      setState(() {
        _config = widget.config;
        _hasChanges = false;
      });
    }
  }

  void _updateConfig(AppearanceConfig newConfig) {
    setState(() {
      _config = newConfig;
      _hasChanges = true;
    });
  }

  Future<void> _saveConfig() async {
    final success = await ConfigService.instance.writeAppearanceConfig(_config.toJson());
    if (success) {
      widget.onConfigChanged(_config);
      setState(() {
        _hasChanges = false;
      });

      // Notify the main app to reload appearance via DBus
      _notifyMainAppReload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appearance settings saved!')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save settings')));
      }
    }
  }

  /// Notify the main hypr_flutter app to reload appearance settings
  Future<void> _notifyMainAppReload() async {
    try {
      // Use dbus-send to trigger reload
      final result = await Process.run('dbus-send', ['--session', '--dest=com.hyprflutter.Panel', '--type=method_call', '/com/hyprflutter/Panel', 'com.hyprflutter.Panel.Execute', 'string:reload-appearance']);

      if (result.exitCode == 0) {
        print('[AppearanceScreen] ✓ Notified main app to reload appearance');
      } else {
        print('[AppearanceScreen] ✗ Failed to notify main app: ${result.stderr}');
      }
    } catch (e) {
      print('[AppearanceScreen] Error notifying main app: $e');
    }
  }

  void _resetConfig() {
    setState(() {
      _config = widget.config;
      _hasChanges = false;
    });
  }

  void _restoreDefaults() {
    setState(() {
      _config = AppearanceConfig();
      _hasChanges = true;
    });
  }

  Future<void> _showColorPicker(Color currentColor, Function(Color) onColorChanged) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(pickerColor: currentColor, onColorChanged: onColorChanged, pickerAreaHeightPercent: 0.8),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance Settings'),
        actions: [
          if (_hasChanges) ...[
            TextButton.icon(icon: const Icon(Icons.refresh), label: const Text('Reset'), onPressed: _resetConfig),
            const SizedBox(width: 8),
            FilledButton.icon(icon: const Icon(Icons.save), label: const Text('Save'), onPressed: _saveConfig),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection(
            title: 'Theme',
            children: [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme colors'),
                value: _config.darkMode,
                onChanged: (value) {
                  _updateConfig(_config.copyWith(darkMode: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Colors',
            children: [
              _buildColorTile('Primary Color', 'Main accent color for the interface', _config.primaryColor, (color) => _updateConfig(_config.copyWith(primaryColor: color))),
              _buildColorTile('Accent Color', 'Secondary accent color', _config.accentColor, (color) => _updateConfig(_config.copyWith(accentColor: color))),
              _buildColorTile('Background Color', 'Main background color', _config.backgroundColor, (color) => _updateConfig(_config.copyWith(backgroundColor: color))),
              _buildColorTile('Container Color', 'Color for panels and containers', _config.containerColor, (color) => _updateConfig(_config.copyWith(containerColor: color))),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Taskbar',
            children: [
              ListTile(title: const Text('Taskbar Opacity'), subtitle: Text('${(_config.taskbarOpacity * 100).round()}%')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Slider(
                  value: _config.taskbarOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(_config.taskbarOpacity * 100).round()}%',
                  onChanged: (value) {
                    _updateConfig(_config.copyWith(taskbarOpacity: value));
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Blur'),
                subtitle: const Text('Apply blur effect to taskbar'),
                value: _config.enableBlur,
                onChanged: (value) {
                  _updateConfig(_config.copyWith(enableBlur: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Clock',
            children: [
              SwitchListTile(
                title: const Text('Show Seconds'),
                subtitle: const Text('Display seconds in the taskbar clock'),
                value: _config.showSecondsOnClock,
                onChanged: (value) {
                  _updateConfig(_config.copyWith(showSecondsOnClock: value));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(icon: const Icon(Icons.restore), label: const Text('Restore Default Settings'), onPressed: _restoreDefaults),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildColorTile(String title, String subtitle, Color color, Function(Color) onColorChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: InkWell(
        onTap: () async {
          Color pickerColor = color;
          await _showColorPicker(color, (newColor) {
            pickerColor = newColor;
          });
          onColorChanged(pickerColor);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor, width: 2),
          ),
        ),
      ),
    );
  }
}

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/windows/settings/settings_controller.dart';
import 'package:hypr_flutter/windows/settings/settings_models.dart';
import 'package:hypr_flutter/windows/settings/widgets/color_selector.dart';
import 'package:hypr_flutter/windows/settings/widgets/display_manager_page.dart';
import 'package:hypr_flutter/windows/settings/widgets/settings_section.dart';
import 'package:hypr_flutter/windows/settings/widgets/toggles.dart';
import 'package:hypr_flutter/window_ids.dart';

class SettingsWindow extends StatefulWidget {
  const SettingsWindow({super.key});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  late final SettingsController _controller;
  bool _closing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.keyQ): const CancelIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyD): const SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          CancelIntent: CallbackAction<CancelIntent>(onInvoke: (_) {
            _discardAndClose();
            return null;
          }),
          SaveIntent: CallbackAction<SaveIntent>(onInvoke: (_) {
            _saveAndApply();
            return null;
          }),
        },
        child: FocusScope(
          autofocus: true,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (!_controller.isLoaded) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              return Theme(
                data: _controller.themeData,
                child: _buildScaffold(context),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final bool requiresRestart = _controller.requiresRestart;
    final bool requiresReload = _controller.requiresReload && !requiresRestart;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Appearance'),
              Tab(text: 'Layout'),
              Tab(text: 'Displays'),
            ],
          ),
          actions: [
            IconButton(
              icon: _closing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.close),
              tooltip: 'Cancel (Q)',
              onPressed: _closing ? null : _discardAndClose,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAppearanceTab(),
            _buildLayoutTab(),
            const DisplayManagerPage(),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _closing ? null : _discardAndClose,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel (Q)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_closing || _saving || !_controller.isDirty) ? null : _saveAndApply,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(requiresRestart ? Icons.restart_alt : (requiresReload ? Icons.refresh : Icons.check)),
                  label: Text(_buildSaveLabel(requiresRestart: requiresRestart, requiresReload: requiresReload)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSaveLabel({required bool requiresRestart, required bool requiresReload}) {
    if (requiresRestart) {
      return 'Save & Restart (D)';
    }
    if (requiresReload) {
      return 'Save & Reload (D)';
    }
    return 'Save (D)';
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Theme',
          children: [
            SettingsSwitchTile(
              title: 'Dark mode',
              subtitle: 'Switch between dark and light theme',
              value: _controller.darkModeEnabled,
              onChanged: _controller.toggleDarkMode,
            ),
            SettingsSwitchTile(
              title: 'Window blur',
              subtitle: 'Enable blur for translucent surfaces',
              value: _controller.enableBlur,
              onChanged: _controller.toggleBlur,
            ),
            ColorSelectorTile(
              title: 'Primary color',
              color: _controller.primaryColor,
              onColorPicked: _controller.updatePrimaryColor,
            ),
            ColorSelectorTile(
              title: 'Secondary color',
              color: _controller.accentColor,
              onColorPicked: _controller.updateAccentColor,
            ),
            ColorSelectorTile(
              title: 'Background color',
              color: _controller.backgroundColor,
              onColorPicked: _controller.updateBackgroundColor,
            ),
            ColorSelectorTile(
              title: 'Container color',
              color: _controller.containerColor,
              onColorPicked: _controller.updateContainerColor,
            ),
          ],
        ),
        SettingsSection(
          title: 'Clock',
          children: [
            SettingsSwitchTile(
              title: 'Show seconds',
              value: _controller.showSecondsOnClock,
              onChanged: _controller.toggleShowSeconds,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayoutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'Taskbar',
          children: [
            SettingsSliderTile(
              title: 'Opacity',
              value: _controller.taskbarOpacity,
              min: 0.2,
              max: 1,
              divisions: 16,
              formatter: (value) => '${(value * 100).round()}%',
              onChanged: _controller.updateTaskbarOpacity,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Navbar position'),
              trailing: DropdownButton<NavbarPosition>(
                value: _controller.navbarPosition,
                onChanged: (position) {
                  if (position != null) {
                    _controller.setNavbarPosition(position);
                  }
                },
                items: NavbarPosition.values
                    .map(
                      (pos) => DropdownMenuItem<NavbarPosition>(
                        value: pos,
                        child: Text(pos.label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _discardAndClose() async {
    _controller.discardChanges();
    await _closeWindow();
  }

  Future<void> _saveAndApply() async {
    setState(() => _saving = true);
    try {
      final result = await _controller.saveChanges();
      if (result.requiresRestart) {
        await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.settings);
        // TODO: invoke shell restart
      } else if (result.requiresReload) {
        // TODO: send message to trigger shell reload/theme update
      }
      await _closeWindow();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _closeWindow() async {
    setState(() => _closing = true);
    try {
      await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.settings);
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class CancelIntent extends Intent {
  const CancelIntent();
}

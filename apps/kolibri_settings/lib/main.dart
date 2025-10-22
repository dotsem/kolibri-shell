import 'package:flutter/material.dart';
import 'models/appearance_config.dart';
import 'services/config_service.dart';
import 'screens/appearance_screen.dart';
import 'screens/display_canvas_screen.dart';
import 'screens/general_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KolibriSettingsApp());
}

class KolibriSettingsApp extends StatefulWidget {
  const KolibriSettingsApp({super.key});

  @override
  State<KolibriSettingsApp> createState() => _KolibriSettingsAppState();
}

class _KolibriSettingsAppState extends State<KolibriSettingsApp> {
  AppearanceConfig _appearanceConfig = AppearanceConfig();

  @override
  void initState() {
    super.initState();
    _loadAppearanceConfig();
  }

  Future<void> _loadAppearanceConfig() async {
    final data = await ConfigService.instance.readAppearanceConfig();
    if (data != null) {
      setState(() {
        _appearanceConfig = AppearanceConfig.fromJson(data);
      });
    }
  }

  void _updateAppearanceConfig(AppearanceConfig config) {
    setState(() {
      _appearanceConfig = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kolibri Settings',
      theme: _appearanceConfig.toThemeData(),
      home: SettingsHome(appearanceConfig: _appearanceConfig, onAppearanceConfigChanged: _updateAppearanceConfig),
    );
  }
}

class SettingsHome extends StatefulWidget {
  final AppearanceConfig appearanceConfig;
  final Function(AppearanceConfig) onAppearanceConfigChanged;

  const SettingsHome({super.key, required this.appearanceConfig, required this.onAppearanceConfigChanged});

  @override
  State<SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<SettingsHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [AppearanceScreen(config: widget.appearanceConfig, onConfigChanged: widget.onAppearanceConfigChanged), const DisplayCanvasScreen(), const GeneralScreen()];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 20),
                Icon(Icons.settings, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text('Kolibri', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
              ],
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette), label: Text('Appearance')),
              NavigationRailDestination(icon: Icon(Icons.monitor_outlined), selectedIcon: Icon(Icons.monitor), label: Text('Display')),
              NavigationRailDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: Text('General')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }
}

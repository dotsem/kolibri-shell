import 'dart:io';
import 'package:path/path.dart' as path;

/// Centralized configuration directory for all Hypr Flutter apps
String get configDirectory {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return path.join(home, '.config', 'hypr_flutter');
}

/// Config file paths - shared between main app and settings app
String get appearanceConfigPath => path.join(configDirectory, 'appearance.json');
String get displayConfigPath => path.join(configDirectory, 'display.json');
String get generalConfigPath => path.join(configDirectory, 'general.json');
String get vpnConfigPath => path.join(configDirectory, 'vpn.json');
String get hiddenAppsConfigPath => path.join(configDirectory, 'hidden_apps.json');
String get favoriteAppsConfigPath => path.join(configDirectory, 'favorite_apps.json');

/// Hyprland configuration file path
String get hyprlandDisplayConfigPath => path.join(configDirectory, 'hyprland_displays.conf');

/// Ensure config directory exists
Future<void> ensureConfigDirectory() async {
  final dir = Directory(configDirectory);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

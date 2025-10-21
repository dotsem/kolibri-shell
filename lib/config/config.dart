import 'dart:io';
import 'package:path/path.dart' as path;

const int workspacesPerMonitor = 10;
const String hyprFlutterPath = "~/prog/flutter/hypr_flutter";
const String buildPath = "$hyprFlutterPath/build/linux/x64/release/bundle/hypr_flutter";

// Centralized config directory
String get configDirectory {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
  return path.join(home, '.config', 'hypr_flutter');
}

// Config file paths
String get notificationsConfigPath => path.join(configDirectory, 'notifications.json');
String get appearanceConfigPath => path.join(configDirectory, 'appearance.json');
String get vpnConfigPath => path.join(configDirectory, 'vpn.json');
String get systemConfigPath => path.join(configDirectory, 'system.json');
String get displayConfigPath => path.join(configDirectory, 'display.json');
String get generalConfigPath => path.join(configDirectory, 'general.json');
String get hiddenAppsConfigPath => path.join(configDirectory, 'hidden_apps.json');
String get favoriteAppsConfigPath => path.join(configDirectory, 'favorite_apps.json');

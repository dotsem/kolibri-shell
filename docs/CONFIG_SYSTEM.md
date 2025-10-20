# Configuration System

This document describes the centralized configuration system for Hypr Flutter.

## Overview

All application configurations are stored in individual JSON files in `~/.config/hypr_flutter/`. This provides:
- Easy backup and restoration
- Human-readable configuration files
- Modular configuration management
- Simple file-based persistence

## Configuration Files

| File | Purpose |
|------|---------|
| `notifications.json` | Notification settings, filters, and stored notifications |
| `appearance.json` | Theme, colors, and visual preferences |
| `vpn.json` | VPN configurations and credentials |
| `system.json` | System monitoring preferences |
| `display.json` | Display and monitor configurations |
| `general.json` | General application settings |

## Config Manager API

### Initialization

```dart
final configManager = ConfigManager();
await configManager.initialize();
```

### Load Configuration

```dart
// Load entire config file
Map<String, dynamic> config = await configManager.loadConfig(notificationsConfigPath);

// Get specific value
String? value = await configManager.getValue<String>(
  notificationsConfigPath, 
  'silentMode',
  defaultValue: false,
);
```

### Save Configuration

```dart
// Save entire config
await configManager.saveConfig(notificationsConfigPath, {
  'silentMode': true,
  'filter': {...},
});

// Set specific value
await configManager.setValue(notificationsConfigPath, 'silentMode', true);

// Update multiple values
await configManager.updateConfig(notificationsConfigPath, {
  'silentMode': true,
  'maxAge': 24,
});
```

### Other Operations

```dart
// Delete a key
await configManager.deleteKey(notificationsConfigPath, 'oldSetting');

// Clear entire config
await configManager.clearConfig(notificationsConfigPath);

// Check if config exists
bool exists = await configManager.configExists(notificationsConfigPath);

// Export all configs
await configManager.exportConfigs('/path/to/backup');

// Import configs from backup
await configManager.importConfigs('/path/to/backup');
```

### Listeners

```dart
// Add listener for config changes
configManager.addListener(notificationsConfigPath, () {
  print('Config changed!');
});

// Remove listener
configManager.removeListener(notificationsConfigPath, callback);
```

## Notification Service

### Notification Model

```dart
class AppNotification {
  String id;
  String title;
  String body;
  NotificationCategory category;  // system, application, network, security, media, message, other
  NotificationPriority priority;  // low, normal, high, critical
  DateTime timestamp;
  String? appName;
  String? appIcon;
  Map<String, dynamic>? actions;
  bool read;
}
```

### Filter Settings

```dart
class NotificationFilter {
  Set<NotificationCategory> enabledCategories;  // Which categories to show
  Set<NotificationPriority> enabledPriorities;  // Which priorities to show
  bool showReadNotifications;                    // Show/hide read notifications
  int maxAge;                                    // Max age in hours (0 = no limit)
  List<String> blockedApps;                     // List of blocked app names
}
```

### Usage

```dart
final service = NotificationService();
await service.initialize();

// Add notification
await service.addNotification(AppNotification(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: 'New Message',
  body: 'You have a new message',
  category: NotificationCategory.message,
  priority: NotificationPriority.normal,
  timestamp: DateTime.now(),
  appName: 'Slack',
));

// Get notifications (filtered)
List<AppNotification> notifications = service.notifications;

// Get all notifications (unfiltered)
List<AppNotification> all = service.allNotifications;

// Get unread count
int unread = service.unreadCount;

// Mark as read
await service.markAsRead(notificationId);
await service.markAllAsRead();

// Clear notifications
await service.clearAll();
await service.clearRead();
await service.clearOld(Duration(days: 7));

// Silent mode (blocks all new notifications)
await service.toggleSilentMode();
await service.setSilentMode(true);
bool isSilent = service.silentMode;

// Filter management
await service.toggleCategory(NotificationCategory.system);
await service.togglePriority(NotificationPriority.low);
await service.updateFilter(newFilter);

// Block/unblock apps
await service.blockApp('AppName');
await service.unblockApp('AppName');

// Query notifications
List<AppNotification> unread = service.getUnreadNotifications();
List<AppNotification> security = service.getNotificationsByCategory(NotificationCategory.security);
List<AppNotification> critical = service.getNotificationsByPriority(NotificationPriority.critical);
```

### Using with Provider

```dart
ChangeNotifierProvider.value(
  value: NotificationService(),
  child: Consumer<NotificationService>(
    builder: (context, service, _) {
      return ListView.builder(
        itemCount: service.notifications.length,
        itemBuilder: (context, index) {
          final notification = service.notifications[index];
          return ListTile(
            title: Text(notification.title),
            subtitle: Text(notification.body),
          );
        },
      );
    },
  ),
);
```

## Migration from SharedPreferences

To migrate existing settings from SharedPreferences to the new config system:

1. Create a migration function:

```dart
Future<void> migrateSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final configManager = ConfigManager();
  
  // Migrate appearance settings
  await configManager.saveConfig(appearanceConfigPath, {
    'darkMode': prefs.getBool('appearance.dark_mode') ?? true,
    'primaryColor': prefs.getInt('appearance.primary_color') ?? 0xFF1E88E5,
    'accentColor': prefs.getInt('appearance.accent_color') ?? 0xFFFFB300,
  });
  
  // Migrate other settings...
}
```

2. Run migration on first launch of new version

## Best Practices

1. **Always initialize before use**
   ```dart
   await configManager.initialize();
   ```

2. **Use typed getters with defaults**
   ```dart
   final value = await configManager.getValue<bool>(
     configPath, 
     'key',
     defaultValue: false,
   );
   ```

3. **Batch updates when possible**
   ```dart
   await configManager.updateConfig(configPath, {
     'key1': value1,
     'key2': value2,
   });
   ```

4. **Use listeners for reactive UI**
   ```dart
   configManager.addListener(configPath, () {
     setState(() {});
   });
   ```

5. **Regular backups**
   ```dart
   await configManager.exportConfigs('/backup/path');
   ```

## File Format

All config files use JSON format with 2-space indentation for readability:

```json
{
  "silentMode": false,
  "filter": {
    "enabledCategories": ["system", "application", "security"],
    "enabledPriorities": ["normal", "high", "critical"],
    "showReadNotifications": true,
    "maxAge": 0,
    "blockedApps": []
  },
  "notifications": [
    {
      "id": "1234567890",
      "title": "Test Notification",
      "body": "This is a test",
      "category": "system",
      "priority": "normal",
      "timestamp": "2025-10-20T10:30:00.000Z",
      "appName": "System",
      "read": false
    }
  ]
}
```

## Troubleshooting

### Config directory not created
Run `initialize()` on ConfigManager:
```dart
await ConfigManager().initialize();
```

### Corrupted config file
Delete the corrupted file and restart the app. A new file will be created with defaults.

### Lost configurations
Restore from backup:
```dart
await configManager.importConfigs('/backup/path');
```

# Quick Start Guide - Notification System

## Setup (Already Done ✅)

The notification system is fully implemented and ready to use!

## Test It Out

1. **Run the app:**
   ```bash
   cd /home/sem/prog/flutter/hypr_flutter
   flutter run -d linux
   ```

2. **Navigate to the Home tab** in the left sidebar

3. **Add demo notifications** by clicking the "Add Demo Notifications" button

4. **Try the features:**
   - View different notification types (system, app, network, security, media, message)
   - See the unread count badge
   - Toggle silent mode (orange bell icon)
   - Open filter settings (filter icon)
   - Mark notifications as read
   - Delete notifications
   - Block apps from sending notifications
   - Clear all notifications

## How to Use in Your Code

### Add a notification:

```dart
import 'package:hypr_flutter/services/notification_service.dart';

final service = NotificationService();
await service.initialize();

await service.addNotification(AppNotification(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: 'Your Title',
  body: 'Your message here',
  category: NotificationCategory.system,  // or .application, .network, etc.
  priority: NotificationPriority.normal,  // or .low, .high, .critical
  timestamp: DateTime.now(),
  appName: 'Your App Name',
));
```

### Example: Integrate with VPN service

In `lib/services/openvpn.dart` or `lib/services/vpn_service.dart`, after successful connection:

```dart
await NotificationService().addNotification(AppNotification(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: 'VPN Connected',
  body: 'Successfully connected to ${configName}',
  category: NotificationCategory.network,
  priority: NotificationPriority.normal,
  timestamp: DateTime.now(),
  appName: 'VPN',
));
```

### Check notification count in other widgets:

```dart
import 'package:provider/provider.dart';
import 'package:hypr_flutter/services/notification_service.dart';

// In your widget:
ChangeNotifierProvider.value(
  value: NotificationService(),
  child: Consumer<NotificationService>(
    builder: (context, service, _) {
      return Badge(
        label: Text('${service.unreadCount}'),
        child: Icon(Icons.notifications),
      );
    },
  ),
);
```

## Configuration Files Location

All configs are saved in: `~/.config/hypr_flutter/`

Check it out:
```bash
ls -la ~/.config/hypr_flutter/
cat ~/.config/hypr_flutter/notifications.json
```

## Remove Demo Button (Optional)

Once you're done testing, remove the demo button from:
`lib/panels/sidebar_left/body/home/home.dart`

Just delete these lines:
```dart
// Demo button (can be removed in production)
Padding(
  padding: const EdgeInsets.all(8.0),
  child: ElevatedButton.icon(
    onPressed: () => NotificationDemo.addSampleNotifications(),
    icon: const Icon(Icons.add_alert),
    label: const Text('Add Demo Notifications'),
  ),
),
```

## What's Next?

Consider integrating notifications with:
- VPN connection/disconnection events
- System updates
- Bluetooth device connections
- Network changes
- Battery alerts
- System resource warnings (high CPU/RAM)

## Troubleshooting

**No notifications showing up?**
- Check if silent mode is enabled (orange bell icon)
- Check filter settings - ensure categories/priorities are enabled
- Check console for any initialization errors

**Config directory not created?**
```dart
await ConfigManager().initialize();
```

**Lost configurations?**
- Check `~/.config/hypr_flutter/` for JSON files
- If corrupted, delete the file and restart (will recreate with defaults)

**Want to backup configs?**
```dart
await ConfigManager().exportConfigs('/path/to/backup');
```

## Full Documentation

See `docs/CONFIG_SYSTEM.md` for complete API documentation and examples.

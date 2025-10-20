import 'package:hypr_flutter/services/notification_service.dart';

/// Utility class to add demo notifications for testing
class NotificationDemo {
  static Future<void> addSampleNotifications() async {
    final service = NotificationService();
    await service.initialize();

    // System notifications
    await service.addNotification(
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'System Update Available',
        body: 'A new system update is available. Update now to get the latest features and security patches.',
        category: NotificationCategory.system,
        priority: NotificationPriority.high,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        appName: 'System',
        appIcon: 'system',
      ),
    );

    // Application notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        title: 'VS Code - Extension Updated',
        body: 'The Flutter extension has been updated to version 3.80.0',
        category: NotificationCategory.application,
        priority: NotificationPriority.normal,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        appName: 'VS Code',
        appIcon: 'vscode',
      ),
    );

    // Network notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
        title: 'WiFi Connected',
        body: 'Successfully connected to "Home Network"',
        category: NotificationCategory.network,
        priority: NotificationPriority.low,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        appName: 'Network Manager',
        appIcon: 'network',
      ),
    );

    // Security notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 3).toString(),
        title: 'Security Alert',
        body: 'Unusual login attempt detected from unknown location',
        category: NotificationCategory.security,
        priority: NotificationPriority.critical,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        appName: 'Security',
        appIcon: 'security',
      ),
    );

    // Media notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 4).toString(),
        title: 'Now Playing',
        body: 'The Less I Know The Better - Tame Impala',
        category: NotificationCategory.media,
        priority: NotificationPriority.low,
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        appName: 'Spotify',
        appIcon: 'spotify',
      ),
    );

    // Message notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 5).toString(),
        title: 'New Message',
        body: 'John: Hey, are you available for a call?',
        category: NotificationCategory.message,
        priority: NotificationPriority.high,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        appName: 'Slack',
        appIcon: 'slack',
      ),
    );

    // Other notifications
    await service.addNotification(
      AppNotification(
        id: (DateTime.now().millisecondsSinceEpoch + 6).toString(),
        title: 'Battery Low',
        body: 'Battery level is at 15%. Please charge your device.',
        category: NotificationCategory.other,
        priority: NotificationPriority.normal,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        appName: 'Power Manager',
        appIcon: 'battery',
      ),
    );

    print('Added 7 sample notifications');
  }

  static Future<void> clearAllNotifications() async {
    final service = NotificationService();
    await service.initialize();
    await service.clearAll();
    print('Cleared all notifications');
  }
}

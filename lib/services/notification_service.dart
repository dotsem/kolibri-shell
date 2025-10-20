import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';
import 'package:hypr_flutter/services/config_manager.dart';

/// Notification priority levels
enum NotificationPriority { low, normal, high, critical }

/// Notification category for filtering
enum NotificationCategory { system, application, network, security, media, message, other }

/// A single notification
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final NotificationPriority priority;
  final DateTime timestamp;
  final String? appName;
  final String? appIcon;
  final Map<String, dynamic>? actions;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.category = NotificationCategory.other,
    this.priority = NotificationPriority.normal,
    required this.timestamp,
    this.appName,
    this.appIcon,
    this.actions,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'category': category.name, 'priority': priority.name, 'timestamp': timestamp.toIso8601String(), 'appName': appName, 'appIcon': appIcon, 'actions': actions, 'read': read};

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    category: NotificationCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => NotificationCategory.other),
    priority: NotificationPriority.values.firstWhere((e) => e.name == json['priority'], orElse: () => NotificationPriority.normal),
    timestamp: DateTime.parse(json['timestamp']),
    appName: json['appName'],
    appIcon: json['appIcon'],
    actions: json['actions'],
    read: json['read'] ?? false,
  );
}

/// Notification filter settings
class NotificationFilter {
  Set<NotificationCategory> enabledCategories;
  Set<NotificationPriority> enabledPriorities;
  bool showReadNotifications;
  int maxAge; // Maximum age in hours (0 = no limit)
  List<String> blockedApps;

  NotificationFilter({Set<NotificationCategory>? enabledCategories, Set<NotificationPriority>? enabledPriorities, this.showReadNotifications = true, this.maxAge = 0, List<String>? blockedApps})
    : enabledCategories = enabledCategories ?? NotificationCategory.values.toSet(),
      enabledPriorities = enabledPriorities ?? NotificationPriority.values.toSet(),
      blockedApps = blockedApps ?? [];

  Map<String, dynamic> toJson() => {
    'enabledCategories': enabledCategories.map((e) => e.name).toList(),
    'enabledPriorities': enabledPriorities.map((e) => e.name).toList(),
    'showReadNotifications': showReadNotifications,
    'maxAge': maxAge,
    'blockedApps': blockedApps,
  };

  factory NotificationFilter.fromJson(Map<String, dynamic> json) => NotificationFilter(
    enabledCategories: (json['enabledCategories'] as List?)?.map((e) => NotificationCategory.values.firstWhere((cat) => cat.name == e, orElse: () => NotificationCategory.other)).toSet(),
    enabledPriorities: (json['enabledPriorities'] as List?)?.map((e) => NotificationPriority.values.firstWhere((pri) => pri.name == e, orElse: () => NotificationPriority.normal)).toSet(),
    showReadNotifications: json['showReadNotifications'] ?? true,
    maxAge: json['maxAge'] ?? 0,
    blockedApps: (json['blockedApps'] as List?)?.cast<String>(),
  );
}

/// Notification service managing all notifications
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ConfigManager _configManager = ConfigManager();
  final List<AppNotification> _notifications = [];
  NotificationFilter _filter = NotificationFilter();
  bool _silentMode = false;
  bool _initialized = false;

  List<AppNotification> get notifications => _getFilteredNotifications();
  List<AppNotification> get allNotifications => List.unmodifiable(_notifications);
  NotificationFilter get filter => _filter;
  bool get silentMode => _silentMode;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    await _configManager.initialize();
    await _loadConfig();
    await _loadNotifications();
    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Load configuration
  Future<void> _loadConfig() async {
    final config = await _configManager.getConfig(notificationsConfigPath);

    if (config.containsKey('filter')) {
      _filter = NotificationFilter.fromJson(config['filter']);
    }

    _silentMode = config['silentMode'] ?? false;
  }

  /// Save configuration
  Future<void> _saveConfig() async {
    await _configManager.saveConfig(notificationsConfigPath, {'filter': _filter.toJson(), 'silentMode': _silentMode});
  }

  /// Load stored notifications
  Future<void> _loadNotifications() async {
    final config = await _configManager.getConfig(notificationsConfigPath);

    if (config.containsKey('notifications')) {
      final notifList = config['notifications'] as List;
      _notifications.clear();
      _notifications.addAll(notifList.map((n) => AppNotification.fromJson(n)).toList());

      // Remove old notifications based on maxAge
      if (_filter.maxAge > 0) {
        final cutoff = DateTime.now().subtract(Duration(hours: _filter.maxAge));
        _notifications.removeWhere((n) => n.timestamp.isBefore(cutoff));
      }
    }
  }

  /// Save notifications to disk
  Future<void> _saveNotifications() async {
    final config = await _configManager.getConfig(notificationsConfigPath);
    config['notifications'] = _notifications.map((n) => n.toJson()).toList();
    await _configManager.saveConfig(notificationsConfigPath, config);
  }

  /// Add a new notification
  Future<void> addNotification(AppNotification notification) async {
    // Check if silent mode is enabled
    if (_silentMode) {
      debugPrint('Silent mode enabled, notification blocked: ${notification.title}');
      return;
    }

    // Check if app is blocked
    if (notification.appName != null && _filter.blockedApps.contains(notification.appName)) {
      debugPrint('App blocked: ${notification.appName}');
      return;
    }

    _notifications.insert(0, notification);
    await _saveNotifications();
    notifyListeners();
    debugPrint('Added notification: ${notification.title}');
  }

  /// Remove a notification
  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
    notifyListeners();
  }

  /// Mark notification as read
  Future<void> markAsRead(String id) async {
    final notification = _notifications.firstWhere((n) => n.id == id);
    notification.read = true;
    await _saveNotifications();
    notifyListeners();
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (final notification in _notifications) {
      notification.read = true;
    }
    await _saveNotifications();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
    debugPrint('Cleared all notifications');
  }

  /// Clear read notifications
  Future<void> clearRead() async {
    _notifications.removeWhere((n) => n.read);
    await _saveNotifications();
    notifyListeners();
  }

  /// Clear old notifications
  Future<void> clearOld(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    _notifications.removeWhere((n) => n.timestamp.isBefore(cutoff));
    await _saveNotifications();
    notifyListeners();
  }

  /// Toggle silent mode
  Future<void> toggleSilentMode() async {
    _silentMode = !_silentMode;
    await _saveConfig();
    notifyListeners();
    debugPrint('Silent mode: $_silentMode');
  }

  /// Set silent mode
  Future<void> setSilentMode(bool enabled) async {
    _silentMode = enabled;
    await _saveConfig();
    notifyListeners();
  }

  /// Update filter
  Future<void> updateFilter(NotificationFilter filter) async {
    _filter = filter;
    await _saveConfig();
    notifyListeners();
    debugPrint('Filter updated');
  }

  /// Toggle category filter
  Future<void> toggleCategory(NotificationCategory category) async {
    if (_filter.enabledCategories.contains(category)) {
      _filter.enabledCategories.remove(category);
    } else {
      _filter.enabledCategories.add(category);
    }
    await _saveConfig();
    notifyListeners();
  }

  /// Toggle priority filter
  Future<void> togglePriority(NotificationPriority priority) async {
    if (_filter.enabledPriorities.contains(priority)) {
      _filter.enabledPriorities.remove(priority);
    } else {
      _filter.enabledPriorities.add(priority);
    }
    await _saveConfig();
    notifyListeners();
  }

  /// Block an app
  Future<void> blockApp(String appName) async {
    if (!_filter.blockedApps.contains(appName)) {
      _filter.blockedApps.add(appName);
      await _saveConfig();
      notifyListeners();
    }
  }

  /// Unblock an app
  Future<void> unblockApp(String appName) async {
    _filter.blockedApps.remove(appName);
    await _saveConfig();
    notifyListeners();
  }

  /// Get filtered notifications
  List<AppNotification> _getFilteredNotifications() {
    return _notifications.where((notification) {
      // Filter by category
      if (!_filter.enabledCategories.contains(notification.category)) {
        return false;
      }

      // Filter by priority
      if (!_filter.enabledPriorities.contains(notification.priority)) {
        return false;
      }

      // Filter by read status
      if (!_filter.showReadNotifications && notification.read) {
        return false;
      }

      // Filter by age
      if (_filter.maxAge > 0) {
        final cutoff = DateTime.now().subtract(Duration(hours: _filter.maxAge));
        if (notification.timestamp.isBefore(cutoff)) {
          return false;
        }
      }

      // Filter by blocked apps
      if (notification.appName != null && _filter.blockedApps.contains(notification.appName)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get notifications by category
  List<AppNotification> getNotificationsByCategory(NotificationCategory category) {
    return _notifications.where((n) => n.category == category).toList();
  }

  /// Get notifications by priority
  List<AppNotification> getNotificationsByPriority(NotificationPriority priority) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  /// Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.read).toList();
  }
}

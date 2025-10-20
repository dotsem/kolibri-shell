import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/notification_service.dart';
import 'package:provider/provider.dart';

class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _notificationService,
      child: Consumer<NotificationService>(
        builder: (context, service, _) {
          return Column(
            children: [
              // Header with filter and actions
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(width: 8),
                        if (service.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '${service.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.filter_list), tooltip: 'Filter', onPressed: () => _showFilterSettings(context, service)),
                        IconButton(
                          icon: Icon(service.silentMode ? Icons.notifications_off : Icons.notifications_active),
                          tooltip: service.silentMode ? 'Silent mode on' : 'Silent mode off',
                          color: service.silentMode ? Colors.orange : null,
                          onPressed: () => service.toggleSilentMode(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Notification list
              if (service.notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: service.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = service.notifications[index];
                    return _buildNotificationCard(context, notification, service);
                  },
                ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(onPressed: service.notifications.isEmpty ? null : () => service.clearAll(), label: const Text("Clear All"), icon: const Icon(Icons.clear_all)),
                    ElevatedButton.icon(onPressed: service.unreadCount == 0 ? null : () => service.markAllAsRead(), label: const Text("Mark All Read"), icon: const Icon(Icons.done_all)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification, NotificationService service) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: notification.read ? null : Theme.of(context).colorScheme.primaryContainer.withAlpha(76),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(notification.category),
          child: Icon(_getCategoryIcon(notification.category), color: Colors.white, size: 20),
        ),
        title: Text(notification.title, style: TextStyle(fontWeight: notification.read ? FontWeight.normal : FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Row(
              children: [
                if (notification.appName != null) ...[
                  Icon(Icons.app_shortcut, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(notification.appName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(_formatTimestamp(notification.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            if (!notification.read)
              const PopupMenuItem(
                value: 'read',
                child: Row(children: [Icon(Icons.done), SizedBox(width: 8), Text('Mark as read')]),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('Delete')]),
            ),
            if (notification.appName != null)
              PopupMenuItem(
                value: 'block',
                child: Row(children: [const Icon(Icons.block), const SizedBox(width: 8), Text('Block ${notification.appName}')]),
              ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'read':
                service.markAsRead(notification.id);
                break;
              case 'delete':
                service.removeNotification(notification.id);
                break;
              case 'block':
                if (notification.appName != null) {
                  service.blockApp(notification.appName!);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocked ${notification.appName}')));
                }
                break;
            }
          },
        ),
      ),
    );
  }

  void _showFilterSettings(BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Filters'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...NotificationCategory.values.map((category) {
                return CheckboxListTile(
                  title: Text(_getCategoryName(category)),
                  value: service.filter.enabledCategories.contains(category),
                  onChanged: (value) {
                    service.toggleCategory(category);
                  },
                );
              }),
              const Divider(),
              const Text('Priorities', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...NotificationPriority.values.map((priority) {
                return CheckboxListTile(
                  title: Text(_getPriorityName(priority)),
                  value: service.filter.enabledPriorities.contains(priority),
                  onChanged: (value) {
                    service.togglePriority(priority);
                  },
                );
              }),
              const Divider(),
              SwitchListTile(
                title: const Text('Show read notifications'),
                value: service.filter.showReadNotifications,
                onChanged: (value) {
                  final updatedFilter = NotificationFilter(
                    enabledCategories: service.filter.enabledCategories,
                    enabledPriorities: service.filter.enabledPriorities,
                    showReadNotifications: value,
                    maxAge: service.filter.maxAge,
                    blockedApps: service.filter.blockedApps,
                  );
                  service.updateFilter(updatedFilter);
                },
              ),
              if (service.filter.blockedApps.isNotEmpty) ...[
                const Divider(),
                const Text('Blocked Apps', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...service.filter.blockedApps.map((app) {
                  return ListTile(
                    title: Text(app),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => service.unblockApp(app)),
                  );
                }),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.system:
        return Colors.blue;
      case NotificationCategory.application:
        return Colors.purple;
      case NotificationCategory.network:
        return Colors.green;
      case NotificationCategory.security:
        return Colors.red;
      case NotificationCategory.media:
        return Colors.orange;
      case NotificationCategory.message:
        return Colors.teal;
      case NotificationCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.system:
        return Icons.settings;
      case NotificationCategory.application:
        return Icons.apps;
      case NotificationCategory.network:
        return Icons.wifi;
      case NotificationCategory.security:
        return Icons.security;
      case NotificationCategory.media:
        return Icons.music_note;
      case NotificationCategory.message:
        return Icons.message;
      case NotificationCategory.other:
        return Icons.notifications;
    }
  }

  String _getCategoryName(NotificationCategory category) {
    return category.name[0].toUpperCase() + category.name.substring(1);
  }

  String _getPriorityName(NotificationPriority priority) {
    return priority.name[0].toUpperCase() + priority.name.substring(1);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

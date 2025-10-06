import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/services/sidebar_left/sidebar_left_services.dart';

class LeftSidebarWidget extends StatefulWidget {
  const LeftSidebarWidget({super.key});

  @override
  State<LeftSidebarWidget> createState() => _LeftSidebarWidgetState();
}

class _LeftSidebarWidgetState extends State<LeftSidebarWidget> {
  final SystemUserService _userService = SystemUserService();
  final HyprlandNotificationService _notificationService = HyprlandNotificationService();
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  final TrelloService _trelloService = TrelloService();

  NotificationCategory _selectedCategory = NotificationCategory.system;

  @override
  void initState() {
    super.initState();
    _userService.loadUserInfo();
    _notificationService.initialize();
    _calendarService.fetchUpcomingEvents();
    _trelloService.fetchTodoCards();
  }

  @override
  void dispose() {
    _userService.dispose();
    _notificationService.dispose();
    _calendarService.dispose();
    _trelloService.dispose();
    super.dispose();
  }

  void _onCategoryChanged(NotificationCategory category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            border: Border(right: BorderSide(color: Colors.grey[700]!, width: 1)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  children: [
                    _UserInfoCard(service: _userService),
                    const SizedBox(height: 12),
                    _NotificationsPanel(
                      service: _notificationService,
                      selected: _selectedCategory,
                      onSelected: _onCategoryChanged,
                    ),
                    const SizedBox(height: 12),
                    _AgendaCard(service: _calendarService),
                    const SizedBox(height: 12),
                    _TrelloTodoCard(service: _trelloService),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[700]!, width: 1)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        'Workspace',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  final SystemUserService service;

  const _UserInfoCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        if (service.loading) {
          return const _SidebarCard(child: _LoadingRow(label: 'Loading user info'));
        }

        return _SidebarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blueGrey.shade600,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.username ?? 'Unknown user',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.hostname ?? 'Unknown host',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  final HyprlandNotificationService service;
  final NotificationCategory selected;
  final ValueChanged<NotificationCategory> onSelected;

  const _NotificationsPanel({required this.service, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final categories = NotificationCategory.values;
        final notifications = service.notificationsFor(selected);

        return _SidebarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Icon(Icons.tune, color: Colors.white54, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: categories.map((category) => category == selected).toList(),
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 28, minWidth: 70),
                onPressed: (index) => onSelected(categories[index]),
                color: Colors.white70,
                selectedColor: Colors.white,
                fillColor: Colors.blueGrey.shade700,
                children: categories
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(category == NotificationCategory.system ? 'System' : 'Social'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              if (service.loading)
                const _LoadingRow(label: 'Fetching notifications')
              else if (notifications.isEmpty)
                Text(
                  'No ${selected == NotificationCategory.system ? 'system' : 'social'} alerts',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                )
              else
                ListView.separated(
                  itemCount: notifications.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final notification = notifications[index];
                    return _NotificationTile(item: notification);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  String _relativeTime(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 1) {
      return 'Just now';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes}m ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours}h ago';
    }
    return '${delta.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.category == NotificationCategory.system ? Icons.settings : Icons.mark_email_unread,
          color: Colors.white70,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _relativeTime(item.timestamp),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final GoogleCalendarService service;

  const _AgendaCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        final events = service.events;

        return _SidebarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Today\'s Agenda', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              if (service.loading)
                const _LoadingRow(label: 'Syncing Google Calendar')
              else if (events.isEmpty)
                const Text('No upcoming events', style: TextStyle(color: Colors.white54, fontSize: 12))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _CalendarEventTile(event: events[index]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  final CalendarEvent event;

  const _CalendarEventTile({required this.event});

  String _formatTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final String timeRange = event.end != null ? '${_formatTime(event.start)} - ${_formatTime(event.end!)}' : _formatTime(event.start);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.title,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(timeRange, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        if (event.location.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(event.location, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ],
    );
  }
}

class _TrelloTodoCard extends StatelessWidget {
  final TrelloService service;

  const _TrelloTodoCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        final todos = service.cards;

        return _SidebarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.checklist, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text('Trello Todos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              if (service.loading)
                const _LoadingRow(label: 'Pulling Trello tasks')
              else if (todos.isEmpty)
                const Text('All caught up! 🎉', style: TextStyle(color: Colors.white54, fontSize: 12))
              else
                ListView.separated(
                  itemCount: todos.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _TrelloTodoTile(item: todos[index]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrelloTodoTile extends StatelessWidget {
  final TrelloCardItem item;

  const _TrelloTodoTile({required this.item});

  String _dueLabel(DateTime due) {
    final delta = due.difference(DateTime.now());
    if (delta.isNegative) {
      return 'Overdue';
    }
    if (delta.inDays >= 1) {
      return 'Due in ${delta.inDays}d';
    }
    return 'Due in ${delta.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(item.listName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              if (item.due != null) ...[
                const SizedBox(height: 2),
                Text(_dueLabel(item.due!), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarCard extends StatelessWidget {
  final Widget child;

  const _SidebarCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final String label;

  const _LoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

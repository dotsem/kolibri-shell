import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class SystemUserService extends ChangeNotifier {
  String? _username;
  String? _hostname;
  bool _loading = true;

  String? get username => _username;
  String? get hostname => _hostname;
  bool get loading => _loading;

  Future<void> loadUserInfo() async {
    _loading = true;
    notifyListeners();

    final envUser = Platform.environment['USER'] ?? Platform.environment['USERNAME'];
    final user = (envUser != null && envUser.isNotEmpty) ? envUser : null;
    final host = Platform.localHostname;

    _username = user ?? 'Unknown User';
    _hostname = host.isNotEmpty ? host : 'Unknown Host';

    _loading = false;
    notifyListeners();
  }
}

enum NotificationCategory { system, social }

class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationCategory category;

  const NotificationItem({required this.title, required this.body, required this.timestamp, required this.category});
}

class HyprlandNotificationService extends ChangeNotifier {
  final Map<NotificationCategory, List<NotificationItem>> _notifications = {
    NotificationCategory.system: <NotificationItem>[],
    NotificationCategory.social: <NotificationItem>[],
  };
  bool _loading = true;

  bool get loading => _loading;

  List<NotificationItem> notificationsFor(NotificationCategory category) => List.unmodifiable(_notifications[category]!);

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    // TODO: Connect to notify-send/Hyprland notification source and populate in realtime.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _notifications[NotificationCategory.system] = [
      NotificationItem(
        title: 'System update ready',
        body: 'Restart required to finish installing updates',
        timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        category: NotificationCategory.system,
      ),
      NotificationItem(
        title: 'Bluetooth device connected',
        body: 'Audio Technica M50xBT',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        category: NotificationCategory.system,
      ),
    ];

    _notifications[NotificationCategory.social] = [
      NotificationItem(
        title: 'New message from Alex',
        body: 'Check out the new design mocks in the channel.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        category: NotificationCategory.social,
      ),
      NotificationItem(
        title: 'Trello card comment',
        body: '“Finalize onboarding flow” received a new comment.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
        category: NotificationCategory.social,
      ),
    ];

    _loading = false;
    notifyListeners();
  }
}

class CalendarEvent {
  final String title;
  final DateTime start;
  final DateTime? end;
  final String location;

  const CalendarEvent({required this.title, required this.start, this.end, this.location = ''});
}

class GoogleCalendarService extends ChangeNotifier {
  final List<CalendarEvent> _events = <CalendarEvent>[];
  bool _loading = true;

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;

  Future<void> fetchUpcomingEvents() async {
    _loading = true;
    notifyListeners();

    // TODO: Replace with Google Calendar API integration.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final now = DateTime.now();
    _events
      ..clear()
      ..addAll([
        CalendarEvent(
          title: 'Product sync with design',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
          location: 'Meet Room 3',
        ),
        CalendarEvent(
          title: 'Daily standup',
          start: now.add(const Duration(hours: 3, minutes: 30)),
          location: 'Discord',
        ),
        CalendarEvent(
          title: '1:1 with manager',
          start: now.add(const Duration(days: 1, hours: 2)),
          location: 'Zoom',
        ),
      ]);

    _loading = false;
    notifyListeners();
  }
}

class TrelloCardItem {
  final String title;
  final DateTime? due;
  final String listName;
  final bool completed;

  const TrelloCardItem({required this.title, required this.listName, this.due, this.completed = false});
}

class TrelloService extends ChangeNotifier {
  final List<TrelloCardItem> _cards = <TrelloCardItem>[];
  bool _loading = true;

  List<TrelloCardItem> get cards => List.unmodifiable(_cards);
  bool get loading => _loading;

  Future<void> fetchTodoCards() async {
    _loading = true;
    notifyListeners();

    // TODO: Replace with Trello REST API call using stored API key/token.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _cards
      ..clear()
      ..addAll([
        TrelloCardItem(
          title: 'Implement settings panel',
          listName: 'In Progress',
          due: DateTime.now().add(const Duration(days: 1)),
        ),
        TrelloCardItem(
          title: 'Review PR #231',
          listName: 'Code Review',
          due: DateTime.now().add(const Duration(hours: 6)),
        ),
        TrelloCardItem(
          title: 'Draft release notes',
          listName: 'To Do',
        ),
      ]);

    _loading = false;
    notifyListeners();
  }
}

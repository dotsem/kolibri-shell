import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/services/settings.dart' show SettingsKeys, SettingsService;

bool? _showSeconds;

class ClockService extends ChangeNotifier {
  static final ClockService _instance = ClockService._internal();

  factory ClockService() => _instance;

  bool _isInitialized = false;
  Timer? _timer;

  ClockService._internal() {
    print("ClockService created in isolate (PID: $pid)");
  }

  /// Initialize the clock service (each isolate runs its own timer)
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    print("ClockService: Starting timer in this isolate");

    // Each isolate runs its own timer - this is fine for clock
    // For heavy services (Bluetooth, WiFi), use longer intervals or event-based updates
    SettingsService().getBool(SettingsKeys.showSecondsOnClock).then((showSeconds) {
      _showSeconds = showSeconds;
      setTimer(showSeconds);
    });
  }

  TaskbarClock _taskbarClock = TaskbarClock.getClock();
  TaskbarClock get now => _taskbarClock;

  setTimer(bool showSeconds) {
    if (showSeconds) {
      _timer = Timer.periodic(Duration(milliseconds: 100), (_) {
        final newClock = TaskbarClock.getClock();

        if (newClock.time != _taskbarClock.time || newClock.date != _taskbarClock.date) {
          _taskbarClock = newClock;
          notifyListeners();
        }
      });
    } else {
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        final newClock = TaskbarClock.getClock();

        if (newClock.time != _taskbarClock.time || newClock.date != _taskbarClock.date) {
          _taskbarClock = newClock;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _isInitialized = false;
    super.dispose();
  }
}

class TaskbarClock {
  String date;
  String time;

  TaskbarClock(this.date, this.time);

  static TaskbarClock getClock() {
    DateTime now = DateTime.now();
    if (_showSeconds == null || !_showSeconds!) return TaskbarClock("${padMePls(now.day)}/${padMePls(now.month)}/${now.year}", "${padMePls(now.hour)}:${padMePls(now.minute)}");
    return TaskbarClock("${padMePls(now.day)}/${padMePls(now.month)}/${now.year}", "${padMePls(now.hour)}:${padMePls(now.minute)}:${padMePls(now.second)}");
  }

  static String padMePls(int time) {
    return time.toString().padLeft(2, "0");
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

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
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      final newClock = TaskbarClock.getClock();
      
      if (newClock.time != _taskbarClock.time || newClock.date != _taskbarClock.date) {
        _taskbarClock = newClock;
        notifyListeners();
      }
    });
  }

  TaskbarClock _taskbarClock = TaskbarClock.getClock();
  TaskbarClock get now => _taskbarClock;
}

class TaskbarClock {
  String date;
  String time;

  TaskbarClock(this.date, this.time);

  static TaskbarClock getClock() {
    DateTime now = DateTime.now();
    return TaskbarClock("${padMePls(now.day)}/${padMePls(now.month)}/${now.year}", "${padMePls(now.hour)}:${padMePls(now.minute)}:${padMePls(now.second)}");
  }

  static String padMePls(int time) {
    return time.toString().padLeft(2, "0");
  }
}

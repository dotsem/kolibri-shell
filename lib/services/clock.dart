import 'dart:async';
import 'package:flutter/foundation.dart';

class ClockService extends ChangeNotifier {
  static final ClockService _instance = ClockService._internal();

  factory ClockService() => _instance;

  ClockService._internal() {
    // Start the timer
    Timer.periodic(Duration(milliseconds: 200), (_) {
      _taskbarClock = TaskbarClock.getClock();
      notifyListeners();
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
    return TaskbarClock(
      "${padMePls(now.day)}/${padMePls(now.month)}/${now.year}",
      "${padMePls(now.hour)}:${padMePls(now.minute)}:${padMePls(now.second)}",
    );
  }

  static String padMePls(int time) {
    return time.toString().padLeft(2, "0");
  }
}

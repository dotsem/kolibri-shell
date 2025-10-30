import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';
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

    // Try to load from config file first, fallback to settings service
    _loadShowSecondsFromConfig().then((showSeconds) {
      _showSeconds = showSeconds;
      setTimer(showSeconds);
    });
  }

  /// Load showSecondsOnClock from appearance config file
  Future<bool> _loadShowSecondsFromConfig() async {
    try {
      final file = File(appearanceConfigPath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final showSeconds = json['showSecondsOnClock'] as bool? ?? false;
        print('[ClockService] Loaded showSeconds from config: $showSeconds');
        return showSeconds;
      }
    } catch (e) {
      print('[ClockService] Error loading config, falling back to settings service: $e');
    }

    // Fallback to settings service
    return await SettingsService().getBool(SettingsKeys.showSecondsOnClock);
  }

  TaskbarClock _taskbarClock = TaskbarClock.getClock();
  TaskbarClock get now => _taskbarClock;

  setTimer(bool showSeconds) {
    _timer?.cancel();

    if (showSeconds) {
      // When showing seconds, only update when seconds actually change
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final newClock = TaskbarClock.getClock();

        if (newClock.time != _taskbarClock.time || newClock.date != _taskbarClock.date) {
          _taskbarClock = newClock;
          notifyListeners();
        }
      });
    } else {
      // When not showing seconds, only check every minute
      final now = DateTime.now();
      final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
      final delayToNextMinute = nextMinute.difference(now);

      // Wait until next minute, then check every minute
      Timer(delayToNextMinute, () {
        _taskbarClock = TaskbarClock.getClock();
        notifyListeners();

        _timer = Timer.periodic(const Duration(minutes: 1), (_) {
          final newClock = TaskbarClock.getClock();
          if (newClock.time != _taskbarClock.time || newClock.date != _taskbarClock.date) {
            _taskbarClock = newClock;
            notifyListeners();
          }
        });
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
    if (_showSeconds == null || !_showSeconds!)
      return TaskbarClock(
        "${padMePls(now.day)}/${padMePls(now.month)}/${now.year}",
        "${padMePls(now.hour)}:${padMePls(now.minute)}",
      );
    return TaskbarClock(
      "${padMePls(now.day)}/${padMePls(now.month)}/${now.year}",
      "${padMePls(now.hour)}:${padMePls(now.minute)}:${padMePls(now.second)}",
    );
  }

  static String padMePls(int time) {
    return time.toString().padLeft(2, "0");
  }
}

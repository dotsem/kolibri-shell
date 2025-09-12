import 'dart:io';

enum BatteryState { unknown, critical, low, charging, discharging, notCharging, full }

class BatteryService {
  int batteryLevel = 0;
  bool hasBattery = false;
  BatteryState batteryState = BatteryState.unknown;

  BatteryService() {
    _hasBattery().then((value) {
      hasBattery = value;
      // if (hasBattery) {
      //   getBatteryInfo().then((value) {
      //     batteryState = _getBatteryState(value);
      //     batteryLevel = _getBatteryLevel(value);
      //   });
      // }
    });
  }

  Future<String> getBatteryInfo() async {
    try {
      // Use upower for battery details
      final result = await Process.run('upower', ['-i', '/org/freedesktop/UPower/devices/battery_BAT0']);
      return result.stdout.toString();
    } catch (e) {
      return "";
    }
  }

  Future<bool> _hasBattery() async {
    try {
      final result = await Process.run('upower', ['-e']);
      return (result.stdout as String).contains("battery");
    } catch (_) {
      return false;
    }
  }
}

import 'dart:io';

/// For managing brightness of monitors. Supports both brightnessctl and ddcutil.
class BrightnessService {
  List<Map<String, String>> ddcMonitors = [];

  /// Detect monitors via ddcutil
  Future<void> detectDdcMonitors() async {
    try {
      final result = await Process.run('ddcutil', ['detect', '--brief']);
      final data = result.stdout.toString().trim();

      ddcMonitors.clear();

      final blocks = data.split('\n\n');
      for (final block in blocks) {
        if (block.startsWith('Display ')) {
          final lines = block.split('\n').map((l) => l.trim()).toList();
          final modelLine = lines.firstWhere((l) => l.startsWith('Monitor:'), orElse: () => '');
          final busLine = lines.firstWhere((l) => l.startsWith('I2C bus:'), orElse: () => '');

          if (modelLine.isNotEmpty && busLine.isNotEmpty) {
            ddcMonitors.add({'model': modelLine.split(':')[2].trim(), 'busNum': busLine.split('/dev/i2c-')[1].trim()});
          }
        }
      }
    } catch (e) {
      stderr.writeln('ddcutil detect error: $e');
    }
  }

  /// Create BrightnessMonitor list from detected screens
  List<BrightnessMonitor> createMonitors() {
    return ddcMonitors.map((m) => BrightnessMonitor(model: m['model'] ?? '', busNum: m['busNum'] ?? '')).toList();
  }
}

class BrightnessMonitor {
  final String model;
  final String busNum;
  double brightness = 0.0;
  bool ready = false;

  BrightnessMonitor({required this.model, required this.busNum});

  /// Initialize monitor by querying current brightness
  Future<void> initialize() async {
    try {
      ProcessResult result;
      if (busNum.isNotEmpty) {
        result = await Process.run('ddcutil', ['-b', busNum, 'getvcp', '10', '--brief']);
      } else {
        result = await Process.run('sh', ['-c', 'echo "a b c \$(brightnessctl g) \$(brightnessctl m)"']);
      }

      final parts = result.stdout.toString().trim().split(' ');
      if (parts.length >= 5) {
        final current = int.tryParse(parts[3]) ?? 0;
        final max = int.tryParse(parts[4]) ?? 1;
        brightness = current / max;
        ready = true;
      }
    } catch (e) {
      stderr.writeln('init brightness error: $e');
    }
  }

  /// Set brightness (0.01–1.0)
  Future<void> setBrightness(double value) async {
    value = value.clamp(0.01, 1.0);
    final rounded = (value * 100).round();
    if ((brightness * 100).round() == rounded) return;

    brightness = value;

    try {
      if (busNum.isNotEmpty) {
        await Process.run('ddcutil', ['-b', busNum, 'setvcp', '10', '$rounded']);
      } else {
        await Process.run('brightnessctl', ['s', '$rounded%', '--quiet']);
      }
    } catch (e) {
      stderr.writeln('set brightness error: $e');
    }
  }
}

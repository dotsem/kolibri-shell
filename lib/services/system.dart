import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class SystemInfoService extends ChangeNotifier {
  static final SystemInfoService _instance = SystemInfoService._internal();
  factory SystemInfoService() => _instance;
  final String distroName = _getDistroName();
  Duration uptime = Duration.zero;

  // Memory
  double memoryTotal = 1;
  double memoryFree = 1;
  double get memoryUsed => memoryTotal - memoryFree;
  double get memoryUsedPercentage => memoryTotal > 0 ? memoryUsed / memoryTotal : 0;

  // Swap
  double swapTotal = 1;
  double swapFree = 1;
  double get swapUsed => swapTotal - swapFree;
  double get swapUsedPercentage => swapTotal > 0 ? swapUsed / swapTotal : 0;

  // CPU
  double cpuUsage = 0;
  List<int>? _previousCpuStats; // [total, idle]

  // Temperature
  double cpuTemp = 0;

  // GPU (NVIDIA/AMD detection)
  double gpuUsage = 0;
  double gpuMemoryUsed = 0;
  double gpuMemoryTotal = 0;

  SystemInfoService._internal() {
    update();
    Timer.periodic(Duration(seconds: 5), (_) => update());
  }

  /// Update all system info
  Future<void> update() async {
    await _updateMemoryAndSwap();
    await _updateCpuUsage();
    await _updateCpuTemp();
    await _updateGpuUsage();
    await _getUptime();
    notifyListeners();
  }

  static String _getDistroName() {
    return Process.runSync('lsb_release', ['-i']).stdout.toString().split(":")[1].trim().toLowerCase();
  }

  /// Memory and swap from /proc/meminfo
  Future<void> _updateMemoryAndSwap() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsLines();

      memoryTotal = _parseLine(meminfo, 'MemTotal');
      memoryFree = _parseLine(meminfo, 'MemAvailable');
      swapTotal = _parseLine(meminfo, 'SwapTotal');
      swapFree = _parseLine(meminfo, 'SwapFree');
    } catch (e) {
      stderr.writeln('Memory update error: $e');
    }
  }

  double _parseLine(List<String> lines, String key) {
    final line = lines.firstWhere((l) => l.startsWith('$key:'), orElse: () => '');
    if (line.isEmpty) return 0;
    final parts = line.split(RegExp(r'\s+'));
    return double.tryParse(parts[1]) ?? 0; // kB
  }

  /// CPU usage from /proc/stat
  Future<void> _updateCpuUsage() async {
    try {
      final statLines = await File('/proc/stat').readAsLines();
      final cpuLine = statLines.firstWhere((l) => l.startsWith('cpu '), orElse: () => '');
      if (cpuLine.isEmpty) return;

      final parts = cpuLine.split(RegExp(r'\s+')).skip(1).map(int.parse).toList();
      final total = parts.reduce((a, b) => a + b);
      final idle = parts[3];

      if (_previousCpuStats != null) {
        final totalDiff = total - _previousCpuStats![0];
        final idleDiff = idle - _previousCpuStats![1];
        cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;
      }

      _previousCpuStats = [total, idle];
    } catch (e) {
      stderr.writeln('CPU usage error: $e');
    }
  }

  /// CPU temperature
  Future<void> _updateCpuTemp() async {
    try {
      final thermalFiles = Directory('/sys/class/thermal').listSync().whereType<File>().where((f) => f.path.contains('temp')).toList();

      if (thermalFiles.isNotEmpty) {
        // Take the first available temp
        final tempString = await thermalFiles.first.readAsString();
        cpuTemp = double.tryParse(tempString.trim()) ?? 0;
        // Usually reported in millidegree
        if (cpuTemp > 1000) cpuTemp /= 1000;
      }
    } catch (e) {
      stderr.writeln('CPU temperature error: $e');
    }
  }

  /// GPU usage (NVIDIA or AMD, best effort)
  Future<void> _updateGpuUsage() async {
    try {
      // NVIDIA (nvidia-smi required)
      final nvidiaResult = await Process.run('nvidia-smi', ['--query-gpu=utilization.gpu,memory.total,memory.used', '--format=csv,noheader,nounits']);

      if (nvidiaResult.exitCode == 0) {
        final line = nvidiaResult.stdout.toString().trim();
        final parts = line.split(',').map((s) => double.tryParse(s.trim()) ?? 0).toList();
        if (parts.length >= 3) {
          gpuUsage = parts[0] / 100;
          gpuMemoryTotal = parts[1];
          gpuMemoryUsed = parts[2];
          return;
        }
      }

      // AMD (rocm-smi or amdgpu-pro tool)
      final amdResult = await Process.run('rocm-smi', ['--showuse']);
      if (amdResult.exitCode == 0) {
        // Implement AMD parsing if needed
      }
    } catch (e) {
      stderr.writeln('GPU usage error: $e');
    }
  }

  Future<void> _getUptime() async {
    final uptimeContent = await File('/proc/uptime').readAsString();
    final seconds = double.parse(uptimeContent.split(' ').first).round();
    uptime = Duration(seconds: seconds);
  }
}

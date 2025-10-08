import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' show basename;

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/window_ids.dart';

class SystemInfoService extends ChangeNotifier {
  static final SystemInfoService _instance = SystemInfoService._internal();
  factory SystemInfoService() => _instance;

  static const int _historyLength = 60;
  static const Duration _updateInterval = Duration(seconds: 1);

  final SettingsService _settings = SettingsService();

  final String distroName = _getDistroName();
  Duration uptime = Duration.zero;

  // Memory
  double memoryTotal = 1;
  double memoryFree = 1;
  double get memoryUsed => memoryTotal - memoryFree;
  double get memoryUsedPercentage => memoryTotal > 0 ? memoryUsed / memoryTotal : 0;
  final List<double> memoryHistory = <double>[];

  // Swap
  double swapTotal = 1;
  double swapFree = 1;
  double get swapUsed => swapTotal - swapFree;
  double get swapUsedPercentage => swapTotal > 0 ? swapUsed / swapTotal : 0;

  // CPU
  double cpuUsage = 0;
  String cpuModel = 'Unknown CPU';
  int cpuCoreCount = 0;
  final List<double> cpuHistory = <double>[];
  final Map<String, _CpuTimes> _previousCpuTimes = <String, _CpuTimes>{};
  final Map<String, CpuCoreUsage> _coreUsageMap = <String, CpuCoreUsage>{};
  List<CpuCoreUsage> cpuCores = <CpuCoreUsage>[];

  // Temperature
  double cpuTemp = 0;

  // GPU (NVIDIA/AMD detection)
  double gpuUsage = 0;
  double gpuMemoryUsed = 0;
  double gpuMemoryTotal = 0;
  double gpuTemp = 0;
  String gpuName = 'Unknown GPU';
  final List<double> gpuHistory = <double>[];
  final List<double> gpuTempHistory = <double>[];

  // Disk usage
  List<DiskUsage> availableDisks = <DiskUsage>[];
  List<DiskUsage> disks = <DiskUsage>[];
  Set<String> _visibleDiskMounts = <String>{};

  bool _updateInProgress = false;
  bool _cpuDetailsExpanded = false;
  bool initialized = false;
  bool _collecting = false;
  bool _collectInBackground = false;
  bool _systemTabActive = false;
  bool _lastSidebarVisible = false;
  bool _evaluatingCollection = false;
  Timer? _updateTimer;
  bool _timerTickInProgress = false;

  SystemInfoService._internal() {
    unawaited(_initialize());
  }

  bool get cpuDetailsExpanded => _cpuDetailsExpanded;
  Set<String> get visibleDiskMounts => _visibleDiskMounts;

  Future<void> _initialize() async {
    await _settings.initialize();
    await Future.wait([_loadCpuInfo(), _loadGpuInfo(), _loadDiskPreferences(), _loadCpuPreferences()]);
    await updateAll(force: true);
  }

  bool get isCollecting => _collecting;
  bool get collectInBackground => _collectInBackground;

  Future<void> setCollectInBackground(bool enabled) async {
    if (_collectInBackground == enabled) {
      return;
    }

    _collectInBackground = enabled;
    await _updateCollectionState();
    notifyListeners();
  }

  Future<void> setSystemTabActive(bool active) async {
    if (_systemTabActive == active) {
      return;
    }

    _systemTabActive = active;
    await _updateCollectionState();
    notifyListeners();
  }

  Future<void> _updateCollectionState() async {
    if (_evaluatingCollection) {
      return;
    }

    _evaluatingCollection = true;
    try {
      final bool sidebarVisible = _systemTabActive ? await _isRightSidebarVisible() : _lastSidebarVisible;
      _lastSidebarVisible = sidebarVisible;
      final bool shouldCollect = (_systemTabActive && sidebarVisible) || _collectInBackground;
      final bool needTimer = _systemTabActive || _collectInBackground;

      _ensureTimer(needTimer);

      if (_collecting != shouldCollect) {
        _collecting = shouldCollect;
        notifyListeners();
      }
    } finally {
      _evaluatingCollection = false;
    }
  }

  void _ensureTimer(bool needTimer) {
    if (needTimer) {
      if (_updateTimer == null) {
        _updateTimer = Timer.periodic(_updateInterval, (_) => _handleTimerTick());
      }
    } else {
      _updateTimer?.cancel();
      _updateTimer = null;
    }
  }

  void _handleTimerTick() {
    if (_timerTickInProgress) {
      return;
    }

    _timerTickInProgress = true;
    _onTimerTick().whenComplete(() {
      _timerTickInProgress = false;
    });
  }

  Future<void> _onTimerTick() async {
    await _updateCollectionState();
    if (_collecting) {
      await updateAll();
    }
  }

  Future<bool> _isRightSidebarVisible() async {
    try {
      return await FlLinuxWindowManager.instance.isVisible(windowId: WindowIds.rightSidebar);
    } catch (_) {
      return false;
    }
  }

  Future<void> setCpuDetailsExpanded(bool expanded) async {
    if (_cpuDetailsExpanded == expanded) return;
    _cpuDetailsExpanded = expanded;
    await _settings.setBool(SettingsKeys.expandCpuSection, expanded);
    notifyListeners();
  }

  Future<void> setVisibleDisks(Set<String> mountPoints) async {
    final allMounts = availableDisks.map((disk) => disk.mountPoint).toSet();
    final normalized = mountPoints.intersection(allMounts);

    if (normalized.isEmpty || normalized.length == allMounts.length) {
      _visibleDiskMounts = <String>{};
      await _settings.remove(SettingsKeys.visibleDisks);
    } else {
      _visibleDiskMounts = normalized;
      await _settings.setStringList(SettingsKeys.visibleDisks, normalized.toList()..sort());
    }

    _refreshVisibleDisks();
    notifyListeners();
  }

  Future<void> _loadDiskPreferences() async {
    final saved = await _settings.getStringList(SettingsKeys.visibleDisks);
    _visibleDiskMounts = saved.toSet();
  }

  Future<void> _loadCpuPreferences() async {
    _cpuDetailsExpanded = await _settings.getBool(SettingsKeys.expandCpuSection);
  }

  Future<void> _loadCpuInfo() async {
    try {
      final cpuInfoFile = File('/proc/cpuinfo');
      if (await cpuInfoFile.exists()) {
        final lines = await cpuInfoFile.readAsLines();
        final modelLine = lines.firstWhere((line) => line.startsWith('model name'), orElse: () => '');
        if (modelLine.isNotEmpty) {
          cpuModel = modelLine.split(':').last.trim();
        }
        cpuCoreCount = lines.where((line) => line.startsWith('processor')).length;
        if (cpuCoreCount == 0) {
          cpuCoreCount = Platform.numberOfProcessors;
        }
        return;
      }
    } catch (_) {
      // Ignore and fallback below
    }

    try {
      final result = await Process.run('lscpu', []);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.startsWith('Model name:')) {
            cpuModel = line.split(':').last.trim();
          }
          if (line.startsWith('CPU(s):')) {
            cpuCoreCount = int.tryParse(line.split(':').last.trim()) ?? cpuCoreCount;
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadGpuInfo() async {
    try {
      final nvidiaName = await Process.run('nvidia-smi', ['--query-gpu=name', '--format=csv,noheader']);
      if (nvidiaName.exitCode == 0) {
        final name = nvidiaName.stdout.toString().trim();
        if (name.isNotEmpty) {
          gpuName = name.split('\n').first.trim();
          return;
        }
      }
    } catch (_) {
      // ignore
    }

    try {
      final lspci = await Process.run('lspci', []);
      if (lspci.exitCode == 0) {
        final gpuLine = lspci.stdout.toString().split('\n').firstWhere((line) => line.toLowerCase().contains('vga compatible controller'), orElse: () => '');
        if (gpuLine.isNotEmpty) {
          final parts = gpuLine.split(':');
          gpuName = parts.last.trim();
        }
      }
    } catch (_) {
      // ignore final fallback
    }
  }

  void _refreshVisibleDisks() {
    if (_visibleDiskMounts.isEmpty) {
      disks = availableDisks;
    } else {
      disks = availableDisks.where((disk) => _visibleDiskMounts.contains(disk.mountPoint)).toList();
    }
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

  /// Update all system info
  Future<void> updateAll({bool force = false}) async {
    if (_updateInProgress || (!force && !_collecting)) return;
    _updateInProgress = true;
    try {
      await _updateMemoryAndSwap();
      _pushHistory(memoryHistory, memoryUsedPercentage);
      await _updateCpuUsage();
      _pushHistory(cpuHistory, cpuUsage);
      await _updateGpuUsage();
      _pushHistory(gpuHistory, gpuUsage);
      await _updateTemperatureSensors();
      await _updateDiskUsage();
      await _getUptime();
      initialized = true;
    } finally {
      _updateInProgress = false;
      notifyListeners();
    }
  }

  /// CPU usage from /proc/stat (aggregate + per-core)
  Future<void> _updateCpuUsage() async {
    try {
      final statLines = await File('/proc/stat').readAsLines();
      final cpuLines = statLines.where((line) => line.startsWith('cpu'));

      for (final line in cpuLines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 5) continue;

        final id = parts.first;
        final times = parts.skip(1).map((value) => int.tryParse(value) ?? 0).toList();
        final total = times.fold<int>(0, (sum, value) => sum + value);
        final idle = times.length > 3 ? times[3] : 0;

        final usage = _computeCpuUsage(_previousCpuTimes, id, total, idle);

        if (usage == null) {
          if (RegExp(r'^cpu\d+$').hasMatch(id)) {
            _coreUsageMap.putIfAbsent(id, () => CpuCoreUsage(id));
          }
          continue;
        }

        if (id == 'cpu') {
          cpuUsage = usage;
        } else if (RegExp(r'^cpu\d+$').hasMatch(id)) {
          final core = _coreUsageMap.putIfAbsent(id, () => CpuCoreUsage(id));
          core.usage = usage;
          _pushHistory(core.history, usage);
        }
      }

      final cores = _coreUsageMap.values.toList()
        ..sort((a, b) {
          final aIndex = int.tryParse(a.id.replaceFirst('cpu', '')) ?? 0;
          final bIndex = int.tryParse(b.id.replaceFirst('cpu', '')) ?? 0;
          return aIndex.compareTo(bIndex);
        });
      cpuCores = cores;
      cpuCoreCount = cores.length;
    } catch (e) {
      stderr.writeln('CPU usage error: $e');
    }
  }

  /// GPU usage (NVIDIA or AMD, best effort)
  Future<void> _updateGpuUsage() async {
    try {
      final nvidiaResult = await Process.run('nvidia-smi', ['--query-gpu=utilization.gpu,memory.total,memory.used,temperature.gpu,name', '--format=csv,noheader,nounits']);

      if (nvidiaResult.exitCode == 0) {
        final line = nvidiaResult.stdout.toString().trim();
        final parts = line.split(',').map((s) => s.trim()).toList();
        if (parts.length >= 5) {
          gpuUsage = (double.tryParse(parts[0]) ?? 0) / 100;
          gpuMemoryTotal = double.tryParse(parts[1]) ?? 0;
          gpuMemoryUsed = double.tryParse(parts[2]) ?? 0;
          gpuTemp = double.tryParse(parts[3]) ?? gpuTemp;
          gpuName = parts[4];
          return;
        }
      }

      final amdResult = await Process.run('rocm-smi', ['--showtemp', '--showuse']);
      if (amdResult.exitCode == 0) {
        final stdout = amdResult.stdout.toString();
        final lines = stdout.split('\n');
        double? temp;
        double? util;
        for (final line in lines) {
          final lower = line.toLowerCase();
          if (lower.contains('temperature')) {
            temp = double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower)?.group(1) ?? '') ?? temp;
          }
          if (lower.contains('use%')) {
            util = double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower)?.group(1) ?? '') ?? util;
          }
        }
        if (temp != null) {
          gpuTemp = temp;
        }
        if (util != null) {
          gpuUsage = util / 100;
        }
      }

      final hwmonGpuTemps = await _readHwmonTemperatures(where: (name) => name.contains('gpu'));
      if (hwmonGpuTemps.isNotEmpty) {
        final drmTemp = hwmonGpuTemps.first;
        gpuTemp = drmTemp.temperature;
      }

      if (gpuTemp > 0 && gpuTemp.isFinite) {
        _pushTemperatureHistory(gpuTempHistory, gpuTemp);
      }
    } catch (e) {
      stderr.writeln('GPU usage error: $e');
    }
  }

  Future<void> _updateTemperatureSensors() async {
    final List<_TempReading> readings = <_TempReading>[];
    try {
      final thermalDir = Directory('/sys/class/thermal');
      if (thermalDir.existsSync()) {
        final entries = await thermalDir.list().where((entity) => entity is Directory && basename(entity.path).startsWith('thermal_zone')).cast<Directory>().toList();

        for (final entry in entries) {
          final reading = await _readThermalZone(entry);
          if (reading != null) {
            readings.add(reading);
          }
        }
      }

      final hwmonReadings = await _readHwmonTemperatures();
      readings.addAll(hwmonReadings);

      double? averageCpuTemp;
      double totalCoreTemp = 0;
      int coreTempCount = 0;

      for (final reading in readings) {
        if (!reading.temperature.isFinite) continue;
        if (!reading.isCpuRelated) {
          continue;
        }

        final lowerLabel = reading.label.toLowerCase();
        final coreMatch = RegExp(r'core\s*(\d+)').firstMatch(lowerLabel);
        if (coreMatch != null) {
          final coreIndex = int.tryParse(coreMatch.group(1) ?? '');
          if (coreIndex != null) {
            final coreId = 'cpu$coreIndex';
            final core = _coreUsageMap.putIfAbsent(coreId, () => CpuCoreUsage(coreId));
            core.temperature = reading.temperature;
            _pushTemperatureHistory(core.tempHistory, reading.temperature);
            totalCoreTemp += reading.temperature;
            coreTempCount++;
          }
          continue;
        }

        if (lowerLabel.contains('package') || lowerLabel.contains('cpu')) {
          averageCpuTemp = reading.temperature;
        }
      }

      if (averageCpuTemp != null) {
        cpuTemp = averageCpuTemp;
      } else if (coreTempCount > 0) {
        cpuTemp = totalCoreTemp / coreTempCount;
      }
    } catch (e) {
      stderr.writeln('Temperature sensors update error: $e');
    }
  }

  Future<_TempReading?> _readThermalZone(Directory directory) async {
    try {
      final typeFile = File('${directory.path}/type');
      final tempFile = File('${directory.path}/temp');

      if (!typeFile.existsSync() || !tempFile.existsSync()) {
        return null;
      }

      final typeText = (await typeFile.readAsString()).trim();
      final tempRaw = await tempFile.readAsString();
      double temp = double.tryParse(tempRaw.trim()) ?? double.nan;
      if (temp > 1000) {
        temp /= 1000;
      }

      final label = await _resolveTempLabel(directory, defaultLabel: typeText);
      final id = 'thermal:${basename(directory.path)}';
      final isCpu = typeText.toLowerCase().contains('cpu') || typeText.toLowerCase().contains('package');

      return _TempReading(id: id, label: label, temperature: temp, isCpuRelated: isCpu);
    } catch (e) {
      stderr.writeln('Thermal zone read error: $e');
      return null;
    }
  }

  Future<List<_TempReading>> _readHwmonTemperatures({bool Function(String name)? where}) async {
    final readings = <_TempReading>[];
    try {
      final hwmonDir = Directory('/sys/class/hwmon');
      if (!hwmonDir.existsSync()) return readings;

      for (final entry in hwmonDir.listSync().whereType<Directory>()) {
        final nameFile = File('${entry.path}/name');
        if (!nameFile.existsSync()) continue;
        final name = (await nameFile.readAsString()).trim().toLowerCase();
        if (where != null && !where(name)) continue;

        final tempInputs = entry.listSync().whereType<File>().where((file) => basename(file.path).startsWith('temp') && file.path.endsWith('_input'));

        for (final file in tempInputs) {
          final value = double.tryParse((await file.readAsString()).trim()) ?? double.nan;
          double temp = value;
          if (temp > 1000) {
            temp /= 1000;
          }

          final labelFile = File(file.path.replaceFirst('_input', '_label'));
          final label = labelFile.existsSync() ? (await labelFile.readAsString()).trim() : '${name.toUpperCase()} ${basename(file.path).replaceAll('_input', '')}';

          final id = 'hwmon:${basename(entry.path)}:${basename(file.path)}';
          readings.add(_TempReading(id: id, label: label, temperature: temp, isCpuRelated: false));
        }
      }
    } catch (e) {
      stderr.writeln('hwmon read error: $e');
    }
    return readings;
  }

  Future<String> _resolveTempLabel(Directory directory, {required String defaultLabel}) async {
    final labelFile = File('${directory.path}/label');
    if (labelFile.existsSync()) {
      return (await labelFile.readAsString()).trim();
    }
    return defaultLabel;
  }

  Future<void> _updateDiskUsage() async {
    try {
      final result = await Process.run('df', ['-kP']);
      if (result.exitCode != 0) {
        stderr.writeln('Disk usage command failed: ${result.stderr}');
        return;
      }

      final lines = result.stdout.toString().split('\n');
      // Skip header line
      final parsed = lines
          .skip(1)
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length < 6) {
              return null;
            }

            final filesystem = parts[0];
            final totalKb = double.tryParse(parts[1]) ?? 0;
            final usedKb = double.tryParse(parts[2]) ?? 0;
            final availableKb = double.tryParse(parts[3]) ?? 0;
            final percentString = parts[4].replaceAll('%', '');
            final mountPoint = parts[5];

            // Ignore special filesystems like tmpfs/devtmpfs except root and home
            if (filesystem.startsWith('tmpfs') || filesystem.startsWith('devtmpfs')) {
              return null;
            }

            final usagePercent = double.tryParse(percentString) ?? 0;

            return DiskUsage(filesystem: filesystem, mountPoint: mountPoint, totalKb: totalKb, usedKb: usedKb, availableKb: availableKb, usagePercent: usagePercent / 100);
          })
          .whereType<DiskUsage>()
          .toList();

      availableDisks = parsed;
      final currentMounts = availableDisks.map((disk) => disk.mountPoint).toSet();
      _visibleDiskMounts = _visibleDiskMounts.intersection(currentMounts);
      _refreshVisibleDisks();
    } catch (e) {
      stderr.writeln('Disk usage error: $e');
    }
  }

  Future<void> _getUptime() async {
    final uptimeContent = await File('/proc/uptime').readAsString();
    final seconds = double.parse(uptimeContent.split(' ').first).round();
    uptime = Duration(seconds: seconds);
  }
}

class DiskUsage {
  DiskUsage({required this.filesystem, required this.mountPoint, required this.totalKb, required this.usedKb, required this.availableKb, required this.usagePercent});

  final String filesystem;
  final String mountPoint;
  final double totalKb;
  final double usedKb;
  final double availableKb;
  final double usagePercent;

  double get totalGb => totalKb / (1024 * 1024);
  double get usedGb => usedKb / (1024 * 1024);
}

class CpuCoreUsage {
  CpuCoreUsage(this.id);

  final String id;
  double usage = 0;
  final List<double> history = <double>[];
  double? temperature;
  final List<double> tempHistory = <double>[];

  String get displayName {
    final match = RegExp(r'cpu(\d+)').firstMatch(id);
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '') ?? 0;
      return 'Core ${index + 1}';
    }
    return id;
  }
}

class _TempReading {
  _TempReading({required this.id, required this.label, required this.temperature, required this.isCpuRelated});

  final String id;
  final String label;
  final double temperature;
  final bool isCpuRelated;
}

void _pushHistory(List<double> history, double value) {
  final normalized = value.clamp(0.0, 1.0);
  history.add(normalized);
  if (history.length > SystemInfoService._historyLength) {
    history.removeRange(0, history.length - SystemInfoService._historyLength);
  }
}

void _pushTemperatureHistory(List<double> history, double value) {
  history.add(value);
  if (history.length > SystemInfoService._historyLength) {
    history.removeRange(0, history.length - SystemInfoService._historyLength);
  }
}

class _CpuTimes {
  const _CpuTimes(this.total, this.idle);

  final int total;
  final int idle;
}

double? _computeCpuUsage(Map<String, _CpuTimes> cache, String id, int total, int idle) {
  final previous = cache[id];
  cache[id] = _CpuTimes(total, idle);
  if (previous == null) {
    return null;
  }

  final totalDiff = total - previous.total;
  final idleDiff = idle - previous.idle;

  if (totalDiff <= 0) {
    return null;
  }

  final usage = 1 - idleDiff / totalDiff;
  return usage.clamp(0.0, 1.0);
}

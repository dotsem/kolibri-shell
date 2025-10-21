import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/config/config.dart';
import 'package:hypr_flutter/services/config_manager.dart';

/// System health status levels
enum HealthStatus {
  excellent, // All checks passed
  good, // Minor issues
  warning, // Some issues need attention
  critical, // Urgent issues
}

/// Package manager type detection
enum PackageManager {
  apt, // Debian/Ubuntu
  pacman, // Arch-based
  dnf, // Fedora/RHEL
  zypper, // openSUSE
  nix, // NixOS
  unknown,
}

/// Battery health information
class BatteryHealth {
  final bool present;
  final int currentCapacity; // in mAh
  final int designCapacity; // in mAh
  final double healthPercentage;
  final int cycleCount;
  final String status; // Charging, Discharging, Full, etc.
  final int chargeLevel; // 0-100
  final bool isCharging;

  BatteryHealth({required this.present, required this.currentCapacity, required this.designCapacity, required this.healthPercentage, required this.cycleCount, required this.status, required this.chargeLevel, required this.isCharging});

  HealthStatus get healthStatus {
    if (!present) return HealthStatus.good;
    if (healthPercentage >= 90) return HealthStatus.excellent;
    if (healthPercentage >= 75) return HealthStatus.good;
    if (healthPercentage >= 60) return HealthStatus.warning;
    return HealthStatus.critical;
  }
}

/// Disk health information
class DiskHealth {
  final String device;
  final String mountPoint;
  final int totalSpace; // in bytes
  final int usedSpace; // in bytes
  final int freeSpace; // in bytes
  final double usagePercentage;
  final bool smart; // SMART health status (true = healthy)
  final int? temperature;
  final int? powerOnHours;

  DiskHealth({required this.device, required this.mountPoint, required this.totalSpace, required this.usedSpace, required this.freeSpace, required this.usagePercentage, required this.smart, this.temperature, this.powerOnHours});

  HealthStatus get healthStatus {
    if (!smart) return HealthStatus.critical;
    if (usagePercentage >= 95) return HealthStatus.critical;
    if (usagePercentage >= 85) return HealthStatus.warning;
    if (usagePercentage >= 70) return HealthStatus.good;
    return HealthStatus.excellent;
  }
}

/// Package update information
class PackageUpdates {
  final int totalUpdates;
  final int securityUpdates;
  final List<String> packages;
  final DateTime lastChecked;

  PackageUpdates({required this.totalUpdates, required this.securityUpdates, required this.packages, required this.lastChecked});

  HealthStatus get healthStatus {
    if (securityUpdates > 10) return HealthStatus.critical;
    if (securityUpdates > 0) return HealthStatus.warning;
    if (totalUpdates > 50) return HealthStatus.warning;
    if (totalUpdates > 20) return HealthStatus.good;
    return HealthStatus.excellent;
  }
}

/// Kernel version information
class KernelInfo {
  final String currentVersion;
  final String latestAvailable;
  final bool isLatest;
  final bool isLTS;
  final String releaseDate;

  KernelInfo({required this.currentVersion, required this.latestAvailable, required this.isLatest, required this.isLTS, required this.releaseDate});

  HealthStatus get healthStatus {
    if (isLatest) return HealthStatus.excellent;
    // Parse versions to check how far behind
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(latestAvailable);
    if (latest[0] > current[0]) return HealthStatus.warning; // Major version behind
    if (latest[1] > current[1] + 5) return HealthStatus.warning; // Many minor versions behind
    return HealthStatus.good;
  }

  List<int> _parseVersion(String version) {
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(version);
    if (match == null) return [0, 0];
    return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
  }
}

/// System services health
class ServicesHealth {
  final List<String> failedServices;
  final int totalServices;
  final int activeServices;

  ServicesHealth({required this.failedServices, required this.totalServices, required this.activeServices});

  HealthStatus get healthStatus {
    if (failedServices.isEmpty) return HealthStatus.excellent;
    if (failedServices.length <= 2) return HealthStatus.good;
    if (failedServices.length <= 5) return HealthStatus.warning;
    return HealthStatus.critical;
  }
}

/// Overall system health
class SystemHealth {
  final BatteryHealth? battery;
  final List<DiskHealth> disks;
  final PackageUpdates packages;
  final KernelInfo kernel;
  final ServicesHealth services;
  final double cpuTemp;
  final double memoryUsage;
  final DateTime lastCheck;

  SystemHealth({this.battery, required this.disks, required this.packages, required this.kernel, required this.services, required this.cpuTemp, required this.memoryUsage, required this.lastCheck});

  HealthStatus get overallStatus {
    final statuses = <HealthStatus>[if (battery != null) battery!.healthStatus, ...disks.map((d) => d.healthStatus), packages.healthStatus, kernel.healthStatus, services.healthStatus];

    if (statuses.any((s) => s == HealthStatus.critical)) return HealthStatus.critical;
    if (statuses.any((s) => s == HealthStatus.warning)) return HealthStatus.warning;
    if (statuses.any((s) => s == HealthStatus.good)) return HealthStatus.good;
    return HealthStatus.excellent;
  }

  int get issueCount {
    int count = 0;
    if (battery != null && battery!.healthStatus != HealthStatus.excellent) count++;
    count += disks.where((d) => d.healthStatus != HealthStatus.excellent).length;
    if (packages.healthStatus != HealthStatus.excellent) count++;
    if (kernel.healthStatus != HealthStatus.excellent) count++;
    if (services.healthStatus != HealthStatus.excellent) count++;
    return count;
  }

  /// Get list of all issues with descriptions
  List<HealthIssue> get issues {
    final issuesList = <HealthIssue>[];

    // Battery issues
    if (battery != null && battery!.healthStatus != HealthStatus.excellent) {
      issuesList.add(HealthIssue(title: 'Battery Health Degraded', description: 'Battery health is at ${battery!.healthPercentage.toStringAsFixed(1)}% with ${battery!.cycleCount} cycles', status: battery!.healthStatus, component: 'Battery'));
    }

    // Disk issues
    for (final disk in disks) {
      if (disk.healthStatus == HealthStatus.critical) {
        if (!disk.smart) {
          issuesList.add(HealthIssue(title: 'Disk SMART Failure', description: 'SMART health check failed for ${disk.device} (${disk.mountPoint})', status: HealthStatus.critical, component: 'Disk'));
        } else if (disk.usagePercentage >= 95) {
          issuesList.add(HealthIssue(title: 'Disk Almost Full', description: '${disk.mountPoint} is ${disk.usagePercentage.toStringAsFixed(1)}% full', status: HealthStatus.critical, component: 'Disk'));
        }
      } else if (disk.healthStatus == HealthStatus.warning) {
        issuesList.add(HealthIssue(title: 'Disk Space Low', description: '${disk.mountPoint} is ${disk.usagePercentage.toStringAsFixed(1)}% full', status: HealthStatus.warning, component: 'Disk'));
      }
    }

    // Package update issues
    if (packages.securityUpdates > 0) {
      issuesList.add(
        HealthIssue(
          title: 'Security Updates Available',
          description: '${packages.securityUpdates} critical security update${packages.securityUpdates > 1 ? 's' : ''} available',
          status: packages.securityUpdates > 10 ? HealthStatus.critical : HealthStatus.warning,
          component: 'Packages',
        ),
      );
    } else if (packages.totalUpdates > 50) {
      issuesList.add(HealthIssue(title: 'Many Updates Available', description: '${packages.totalUpdates} package updates available', status: HealthStatus.warning, component: 'Packages'));
    } else if (packages.totalUpdates > 20) {
      issuesList.add(HealthIssue(title: 'Updates Available', description: '${packages.totalUpdates} package updates available', status: HealthStatus.good, component: 'Packages'));
    }

    // Kernel issues
    if (!kernel.isLatest) {
      issuesList.add(HealthIssue(title: 'Kernel Outdated', description: 'Running ${kernel.currentVersion}, latest is ${kernel.latestAvailable}', status: kernel.healthStatus, component: 'Kernel'));
    }

    // Service issues
    if (services.failedServices.isNotEmpty) {
      issuesList.add(
        HealthIssue(
          title: 'Failed System Services',
          description: '${services.failedServices.length} service${services.failedServices.length > 1 ? 's' : ''} failed: ${services.failedServices.take(3).join(", ")}${services.failedServices.length > 3 ? "..." : ""}',
          status: services.healthStatus,
          component: 'Services',
        ),
      );
    }

    return issuesList;
  }

  /// Get critical issues only
  List<HealthIssue> get criticalIssues => issues.where((i) => i.status == HealthStatus.critical).toList();

  /// Get warning issues only
  List<HealthIssue> get warningIssues => issues.where((i) => i.status == HealthStatus.warning).toList();
}

/// Individual health issue
class HealthIssue {
  final String title;
  final String description;
  final HealthStatus status;
  final String component;

  HealthIssue({required this.title, required this.description, required this.status, required this.component});
}

/// System health monitoring service
class SystemHealthService extends ChangeNotifier {
  static final SystemHealthService _instance = SystemHealthService._internal();
  factory SystemHealthService() => _instance;
  SystemHealthService._internal();

  final ConfigManager _configManager = ConfigManager();

  SystemHealth? _currentHealth;
  bool _isChecking = false;
  Timer? _autoCheckTimer;
  PackageManager _packageManager = PackageManager.unknown;

  SystemHealth? get currentHealth => _currentHealth;
  bool get isChecking => _isChecking;
  PackageManager get packageManager => _packageManager;

  /// Initialize the service
  Future<void> initialize() async {
    await _configManager.initialize();
    _packageManager = await _detectPackageManager();
    await checkHealth();

    // Auto-check every 30 minutes
    _autoCheckTimer = Timer.periodic(const Duration(minutes: 30), (_) => checkHealth());

    debugPrint('SystemHealthService initialized with package manager: $_packageManager');
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  /// Detect which package manager is being used
  Future<PackageManager> _detectPackageManager() async {
    try {
      // Check for apt (Debian/Ubuntu)
      final aptCheck = await Process.run('which', ['apt']);
      if (aptCheck.exitCode == 0) return PackageManager.apt;

      // Check for pacman (Arch)
      final pacmanCheck = await Process.run('which', ['pacman']);
      if (pacmanCheck.exitCode == 0) return PackageManager.pacman;

      // Check for dnf (Fedora/RHEL)
      final dnfCheck = await Process.run('which', ['dnf']);
      if (dnfCheck.exitCode == 0) return PackageManager.dnf;

      // Check for zypper (openSUSE)
      final zypperCheck = await Process.run('which', ['zypper']);
      if (zypperCheck.exitCode == 0) return PackageManager.zypper;

      // Check for nix (NixOS)
      final nixCheck = await Process.run('which', ['nix-env']);
      if (nixCheck.exitCode == 0) return PackageManager.nix;

      return PackageManager.unknown;
    } catch (e) {
      debugPrint('Error detecting package manager: $e');
      return PackageManager.unknown;
    }
  }

  /// Perform full system health check
  Future<void> checkHealth() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      final results = await Future.wait([_checkBattery(), _checkDisks(), _checkPackageUpdates(), _checkKernel(), _checkServices(), _getCpuTemp(), _getMemoryUsage()]);

      _currentHealth = SystemHealth(
        battery: results[0] as BatteryHealth?,
        disks: results[1] as List<DiskHealth>,
        packages: results[2] as PackageUpdates,
        kernel: results[3] as KernelInfo,
        services: results[4] as ServicesHealth,
        cpuTemp: results[5] as double,
        memoryUsage: results[6] as double,
        lastCheck: DateTime.now(),
      );

      // Save to config
      await _saveHealthData();
    } catch (e) {
      debugPrint('Error checking system health: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Check battery health
  Future<BatteryHealth?> _checkBattery() async {
    try {
      final batteryPath = Directory('/sys/class/power_supply');
      if (!await batteryPath.exists()) return null;

      // Find battery (usually BAT0 or BAT1)
      final batteries = await batteryPath.list().where((entity) {
        return entity.path.contains('BAT');
      }).toList();

      if (batteries.isEmpty) return null;

      final battery = batteries.first.path;

      final capacity = await _readSysFile('$battery/capacity');
      final status = await _readSysFile('$battery/status');
      final chargeNow = await _readSysFile('$battery/charge_now');
      final chargeFull = await _readSysFile('$battery/charge_full');
      final chargeFullDesign = await _readSysFile('$battery/charge_full_design');
      final cycleCount = await _readSysFile('$battery/cycle_count');

      final currentCap = int.tryParse(chargeNow) ?? 0;
      final fullCap = int.tryParse(chargeFull) ?? 1;
      final designCap = int.tryParse(chargeFullDesign) ?? 1;
      final health = (fullCap / designCap * 100).clamp(0.0, 100.0).toDouble();

      return BatteryHealth(
        present: true,
        currentCapacity: currentCap ~/ 1000, // Convert to mAh
        designCapacity: designCap ~/ 1000,
        healthPercentage: health,
        cycleCount: int.tryParse(cycleCount) ?? 0,
        status: status.trim(),
        chargeLevel: int.tryParse(capacity) ?? 0,
        isCharging: status.trim().toLowerCase() == 'charging',
      );
    } catch (e) {
      debugPrint('Error checking battery: $e');
      return null;
    }
  }

  /// Check disk health
  Future<List<DiskHealth>> _checkDisks() async {
    final disks = <DiskHealth>[];

    try {
      // Get disk usage with df
      final dfResult = await Process.run('df', ['-B1', '-x', 'tmpfs', '-x', 'devtmpfs']);
      if (dfResult.exitCode != 0) return disks;

      final lines = dfResult.stdout.toString().split('\n').skip(1);
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 6) continue;

        final device = parts[0];
        final total = int.tryParse(parts[1]) ?? 0;
        final used = int.tryParse(parts[2]) ?? 0;
        final free = int.tryParse(parts[3]) ?? 0;
        final mountPoint = parts[5];

        // Skip if not a real device
        if (!device.startsWith('/dev/')) continue;

        final usage = (total > 0 ? (used / total * 100) : 0.0).toDouble();

        // Check SMART status if available (requires smartctl)
        bool smartHealthy = true;
        int? temp;
        int? powerOnHours;

        try {
          final smartResult = await Process.run('smartctl', ['-H', '-A', device]);
          if (smartResult.exitCode == 0) {
            final output = smartResult.stdout.toString();
            smartHealthy = output.contains('PASSED');

            // Try to extract temperature
            final tempMatch = RegExp(r'Temperature.*?(\d+)').firstMatch(output);
            if (tempMatch != null) {
              temp = int.tryParse(tempMatch.group(1)!);
            }

            // Try to extract power on hours
            final hoursMatch = RegExp(r'Power_On_Hours.*?(\d+)').firstMatch(output);
            if (hoursMatch != null) {
              powerOnHours = int.tryParse(hoursMatch.group(1)!);
            }
          }
        } catch (e) {
          // smartctl not available or requires sudo
        }

        disks.add(DiskHealth(device: device, mountPoint: mountPoint, totalSpace: total, usedSpace: used, freeSpace: free, usagePercentage: usage, smart: smartHealthy, temperature: temp, powerOnHours: powerOnHours));
      }
    } catch (e) {
      debugPrint('Error checking disks: $e');
    }

    return disks;
  }

  /// Check for package updates
  Future<PackageUpdates> _checkPackageUpdates() async {
    try {
      switch (_packageManager) {
        case PackageManager.apt:
          return await _checkAptUpdates();
        case PackageManager.pacman:
          return await _checkPacmanUpdates();
        case PackageManager.dnf:
          return await _checkDnfUpdates();
        case PackageManager.zypper:
          return await _checkZypperUpdates();
        case PackageManager.nix:
          return await _checkNixUpdates();
        default:
          return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
      }
    } catch (e) {
      debugPrint('Error checking package updates: $e');
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  Future<PackageUpdates> _checkAptUpdates() async {
    try {
      // Check for upgradable packages (no sudo needed)
      final result = await Process.run('apt', ['list', '--upgradable']);
      final lines = result.stdout.toString().split('\n').skip(1).where((l) => l.isNotEmpty).toList();

      // Check for security updates
      final secResult = await Process.run('sh', ['-c', 'apt list --upgradable 2>/dev/null | grep -i security']);
      final secLines = secResult.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();

      return PackageUpdates(
        totalUpdates: lines.length,
        securityUpdates: secLines.length,
        packages: lines.take(50).toList(), // Limit to first 50
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error checking apt updates: $e');
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  Future<PackageUpdates> _checkPacmanUpdates() async {
    try {
      // Check for updates (no sudo needed)
      final result = await Process.run('checkupdates', []);
      if (result.exitCode != 0) {
        // checkupdates not installed, try pacman -Qu directly
        final fallbackResult = await Process.run('checkupdates', []);
        final lines = fallbackResult.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();
        return PackageUpdates(totalUpdates: lines.length, securityUpdates: 0, packages: lines.take(50).toList(), lastChecked: DateTime.now());
      }

      final lines = result.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();

      return PackageUpdates(
        totalUpdates: lines.length,
        securityUpdates: 0, // Arch doesn't distinguish security updates
        packages: lines.take(50).toList(),
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  Future<PackageUpdates> _checkDnfUpdates() async {
    try {
      final result = await Process.run('dnf', ['check-update']);
      final lines = result.stdout.toString().split('\n').skip(1).where((l) => l.isNotEmpty).toList();

      final secResult = await Process.run('dnf', ['updateinfo', 'list', 'security']);
      final secLines = secResult.stdout.toString().split('\n').where((l) => l.isNotEmpty).toList();

      return PackageUpdates(totalUpdates: lines.length, securityUpdates: secLines.length, packages: lines.take(50).toList(), lastChecked: DateTime.now());
    } catch (e) {
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  Future<PackageUpdates> _checkZypperUpdates() async {
    try {
      final result = await Process.run('zypper', ['list-updates']);
      final lines = result.stdout.toString().split('\n').skip(4).where((l) => l.isNotEmpty).toList();

      return PackageUpdates(totalUpdates: lines.length, securityUpdates: 0, packages: lines.take(50).toList(), lastChecked: DateTime.now());
    } catch (e) {
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  Future<PackageUpdates> _checkNixUpdates() async {
    try {
      final result = await Process.run('nix-env', ['-u', '--dry-run']);
      final lines = result.stdout.toString().split('\n').where((l) => l.contains('installing')).toList();

      return PackageUpdates(totalUpdates: lines.length, securityUpdates: 0, packages: lines.take(50).toList(), lastChecked: DateTime.now());
    } catch (e) {
      return PackageUpdates(totalUpdates: 0, securityUpdates: 0, packages: [], lastChecked: DateTime.now());
    }
  }

  /// Check kernel version
  Future<KernelInfo> _checkKernel() async {
    try {
      final unameResult = await Process.run('uname', ['-r']);
      final currentVersion = unameResult.stdout.toString().trim();

      // Try to get latest kernel info from kernel.org
      String latestVersion = currentVersion;
      bool isLatest = true;

      try {
        final curlResult = await Process.run('curl', ['-s', 'https://www.kernel.org/finger_banner']);
        if (curlResult.exitCode == 0) {
          final output = curlResult.stdout.toString();
          final match = RegExp(r'The latest stable version.*?is:\s*(\d+\.\d+\.\d+)').firstMatch(output);
          if (match != null) {
            latestVersion = match.group(1)!;
            isLatest = currentVersion.contains(latestVersion.split('.').take(2).join('.'));
          }
        }
      } catch (e) {
        // Network error or curl not available
      }

      return KernelInfo(currentVersion: currentVersion, latestAvailable: latestVersion, isLatest: isLatest, isLTS: currentVersion.contains('lts') || currentVersion.contains('.0.'), releaseDate: 'Unknown');
    } catch (e) {
      debugPrint('Error checking kernel: $e');
      return KernelInfo(currentVersion: 'Unknown', latestAvailable: 'Unknown', isLatest: true, isLTS: false, releaseDate: 'Unknown');
    }
  }

  /// Check system services (systemd)
  Future<ServicesHealth> _checkServices() async {
    try {
      final result = await Process.run('systemctl', ['list-units', '--failed', '--no-pager']);
      if (result.exitCode != 0) {
        return ServicesHealth(failedServices: [], totalServices: 0, activeServices: 0);
      }

      final lines = result.stdout.toString().split('\n');
      final failedServices = lines.where((l) => l.contains('●') && l.contains('failed')).map((l) => l.split(RegExp(r'\s+'))[1]).toList();

      // Get total services count
      final allResult = await Process.run('systemctl', ['list-units', '--type=service', '--no-pager']);
      final allLines = allResult.stdout.toString().split('\n');
      final totalServices = allLines.where((l) => l.contains('.service')).length;
      final activeServices = allLines.where((l) => l.contains('active')).length;

      return ServicesHealth(failedServices: failedServices, totalServices: totalServices, activeServices: activeServices);
    } catch (e) {
      debugPrint('Error checking services: $e');
      return ServicesHealth(failedServices: [], totalServices: 0, activeServices: 0);
    }
  }

  /// Get CPU temperature
  Future<double> _getCpuTemp() async {
    try {
      final tempPath = '/sys/class/thermal/thermal_zone0/temp';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final temp = await tempFile.readAsString();
        return double.parse(temp.trim()) / 1000;
      }
    } catch (e) {
      debugPrint('Error reading CPU temp: $e');
    }
    return 0;
  }

  /// Get memory usage
  Future<double> _getMemoryUsage() async {
    try {
      final meminfoFile = File('/proc/meminfo');
      if (!await meminfoFile.exists()) return 0;

      final content = await meminfoFile.readAsString();
      final lines = content.split('\n');

      int? memTotal;
      int? memAvailable;

      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          memTotal = int.tryParse(line.split(RegExp(r'\s+'))[1]);
        } else if (line.startsWith('MemAvailable:')) {
          memAvailable = int.tryParse(line.split(RegExp(r'\s+'))[1]);
        }
      }

      if (memTotal != null && memAvailable != null) {
        return ((memTotal - memAvailable) / memTotal * 100);
      }
    } catch (e) {
      debugPrint('Error reading memory usage: $e');
    }
    return 0;
  }

  /// Read a sysfs file
  Future<String> _readSysFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      // File doesn't exist or can't be read
    }
    return '0';
  }

  /// Save health data to config
  Future<void> _saveHealthData() async {
    if (_currentHealth == null) return;

    await _configManager.updateConfig(systemConfigPath, {'lastHealthCheck': _currentHealth!.lastCheck.toIso8601String(), 'overallStatus': _currentHealth!.overallStatus.name, 'issueCount': _currentHealth!.issueCount});
  }

  /// Force update package cache (may require sudo)
  Future<bool> updatePackageCache() async {
    try {
      ProcessResult result;
      switch (_packageManager) {
        case PackageManager.apt:
          result = await Process.run('pkexec', ['apt', 'update']);
          break;
        case PackageManager.pacman:
          result = await Process.run('pkexec', ['pacman', '-Sy']);
          break;
        case PackageManager.dnf:
          result = await Process.run('pkexec', ['dnf', 'check-update']);
          break;
        case PackageManager.zypper:
          result = await Process.run('pkexec', ['zypper', 'refresh']);
          break;
        case PackageManager.nix:
          result = await Process.run('nix-channel', ['--update']);
          break;
        default:
          return false;
      }

      if (result.exitCode == 0 || result.exitCode == 100) {
        await checkHealth();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating package cache: $e');
      return false;
    }
  }
}

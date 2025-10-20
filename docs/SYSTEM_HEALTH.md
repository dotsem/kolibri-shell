# System Health Monitoring

A comprehensive system health monitoring service for Linux systems that checks multiple health indicators.

## Features

### ✅ What's Monitored

1. **Package Updates**
   - Total available updates
   - Security updates (critical!)
   - Package list
   - Supports: apt, pacman, dnf, zypper, nix

2. **Kernel Version**
   - Current kernel version
   - Latest available version
   - LTS status detection
   - Comparison with latest stable

3. **Battery Health** (if present)
   - Battery health percentage
   - Current vs. design capacity
   - Cycle count
   - Charge level
   - Charging status

4. **Disk Health**
   - Space usage for all mounted disks
   - SMART health status (if available)
   - Temperature monitoring
   - Power-on hours

5. **System Services**
   - Failed services detection
   - Total/active service count
   - Systemd integration

6. **System Stats**
   - CPU temperature
   - Memory usage percentage

### Health Status Levels

- **Excellent** (🟢) - All checks passed
- **Good** (🔵) - Minor issues, no action needed
- **Warning** (🟠) - Some issues need attention
- **Critical** (🔴) - Urgent issues require immediate action

## Usage

### Initialize Service

```dart
final healthService = SystemHealthService();
await healthService.initialize();
```

### Check Health

```dart
// Manual check
await healthService.checkHealth();

// Access current health
final health = healthService.currentHealth;
print('Overall status: ${health.overallStatus}');
print('Issues found: ${health.issueCount}');
```

### With Provider

```dart
ChangeNotifierProvider.value(
  value: SystemHealthService(),
  child: Consumer<SystemHealthService>(
    builder: (context, service, _) {
      final health = service.currentHealth;
      if (health == null) return CircularProgressIndicator();
      
      return Text('Status: ${health.overallStatus}');
    },
  ),
);
```

### Health Details

```dart
final health = healthService.currentHealth!;

// Package updates
print('Updates: ${health.packages.totalUpdates}');
print('Security: ${health.packages.securityUpdates}');

// Kernel
print('Kernel: ${health.kernel.currentVersion}');
print('Latest: ${health.kernel.isLatest}');

// Battery (if present)
if (health.battery != null) {
  print('Battery health: ${health.battery!.healthPercentage}%');
  print('Cycles: ${health.battery!.cycleCount}');
}

// Disks
for (final disk in health.disks) {
  print('${disk.mountPoint}: ${disk.usagePercentage}%');
  print('SMART: ${disk.smart ? "OK" : "FAILING"}');
}

// Services
print('Failed services: ${health.services.failedServices}');
```

## Package Manager Detection

The service automatically detects your package manager:

| Distribution | Package Manager | Update Command |
|--------------|----------------|----------------|
| Debian/Ubuntu | apt | `sudo apt update && sudo apt upgrade` |
| Arch/Manjaro | pacman | `sudo pacman -Syu` |
| Fedora/RHEL | dnf | `sudo dnf upgrade` |
| openSUSE | zypper | `sudo zypper update` |
| NixOS | nix | `nix-channel --update && nix-env -u` |

## Health Check Criteria

### Battery

- **Excellent**: ≥90% health
- **Good**: 75-89% health
- **Warning**: 60-74% health
- **Critical**: <60% health

### Disks

- **Excellent**: <70% usage, SMART OK
- **Good**: 70-84% usage, SMART OK
- **Warning**: 85-94% usage or SMART issues
- **Critical**: ≥95% usage or SMART failing

### Packages

- **Excellent**: 0 security updates, <20 total updates
- **Good**: 0 security updates, 20-50 total updates
- **Warning**: 1-10 security updates or >50 total updates
- **Critical**: >10 security updates

### Kernel

- **Excellent**: Latest version
- **Good**: Minor version behind
- **Warning**: Major version behind or many minor versions behind

### Services

- **Excellent**: No failed services
- **Good**: 1-2 failed services
- **Warning**: 3-5 failed services
- **Critical**: >5 failed services

## Permissions

Some features require elevated permissions:

### Package Updates
```bash
# One-time setup to allow checking updates without password:
sudo visudo
# Add line:
yourusername ALL=(ALL) NOPASSWD: /usr/bin/apt update
yourusername ALL=(ALL) NOPASSWD: /usr/bin/pacman -Sy
# etc.
```

### SMART Monitoring
```bash
# Install smartmontools
sudo apt install smartmontools  # Debian/Ubuntu
sudo pacman -S smartmontools    # Arch
```

## Auto-Check

Health checks run automatically every 30 minutes. Disable with:

```dart
healthService.dispose();  // Stops auto-checking
```

## Configuration

Health check history is saved to `~/.config/hypr_flutter/system.json`:

```json
{
  "lastHealthCheck": "2025-10-20T10:30:00.000Z",
  "overallStatus": "excellent",
  "issueCount": 0
}
```

## UI Integration

The health tab shows:

- **Overall health card** with color-coded status
- **Package updates** with expandable list and update commands
- **Kernel version** with latest comparison
- **Battery health** (if present) with detailed stats
- **Disk health** for all mounted drives with usage bars
- **System services** showing failed services
- **System stats** with CPU temp and memory usage
- **Refresh button** to manually trigger check

## Troubleshooting

### "Package updates showing 0 but I have updates"

Check if your package manager database needs updating. The app tries to update automatically but may need sudo permissions.

### "SMART data not available"

Install `smartmontools` and ensure the user has permission to read SMART data:
```bash
sudo chmod +s /usr/sbin/smartctl
```

### "Battery not detected"

Normal for desktop systems. Battery monitoring only works on laptops with `/sys/class/power_supply/BAT*` support.

### "Failed services shown but system is fine"

Some failed services are expected (e.g., optional services that didn't start). Review the list to determine if action is needed.

### "Kernel shows outdated but I'm on latest for my distro"

The check compares against kernel.org's latest stable. Your distribution may intentionally stay on an older, well-tested version (especially LTS).

## API Reference

### SystemHealth Model

```dart
class SystemHealth {
  final BatteryHealth? battery;
  final List<DiskHealth> disks;
  final PackageUpdates packages;
  final KernelInfo kernel;
  final ServicesHealth services;
  final double cpuTemp;
  final double memoryUsage;
  final DateTime lastCheck;
  
  HealthStatus get overallStatus;
  int get issueCount;
}
```

### HealthStatus Enum

```dart
enum HealthStatus {
  excellent,
  good,
  warning,
  critical,
}
```

### PackageManager Enum

```dart
enum PackageManager {
  apt,
  pacman,
  dnf,
  zypper,
  nix,
  unknown,
}
```

## Example: Integrate with Notifications

```dart
// After health check, send notification for critical issues
await healthService.checkHealth();
final health = healthService.currentHealth!;

if (health.overallStatus == HealthStatus.critical) {
  await NotificationService().addNotification(AppNotification(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: 'System Health Critical!',
    body: '${health.issueCount} critical issues detected',
    category: NotificationCategory.system,
    priority: NotificationPriority.critical,
    timestamp: DateTime.now(),
    appName: 'System Health',
  ));
}

if (health.packages.securityUpdates > 0) {
  await NotificationService().addNotification(AppNotification(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: 'Security Updates Available',
    body: '${health.packages.securityUpdates} security updates need installation',
    category: NotificationCategory.security,
    priority: NotificationPriority.high,
    timestamp: DateTime.now(),
    appName: 'System Health',
  ));
}
```

## Performance

- Initial check: 2-5 seconds
- Auto-checks: Every 30 minutes
- Minimal CPU/memory usage when idle
- Results cached between checks

## Future Enhancements

- [ ] Network connectivity checks
- [ ] Docker container health
- [ ] GPU health monitoring
- [ ] Fan speed monitoring
- [ ] System load average tracking
- [ ] Custom health check scripts
- [ ] Email/webhook notifications for critical issues
- [ ] Historical health tracking and graphs

## Credits

Built for Hypr Flutter - A modern Linux desktop environment.

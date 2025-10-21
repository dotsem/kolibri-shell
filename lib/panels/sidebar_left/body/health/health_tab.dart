import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/system_health.dart';
import 'package:provider/provider.dart';

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  final SystemHealthService _healthService = SystemHealthService();

  @override
  void initState() {
    super.initState();
    _healthService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _healthService,
      child: Consumer<SystemHealthService>(
        builder: (context, service, _) {
          if (service.isChecking && service.currentHealth == null) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Checking system health...')]),
            );
          }

          final health = service.currentHealth;
          if (health == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Unable to check system health'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () => service.checkHealth(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => service.checkHealth(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverallHealthCard(context, health, service),
                  const SizedBox(height: 16),
                  _buildPackageUpdatesCard(context, health.packages, service),
                  const SizedBox(height: 16),
                  _buildKernelCard(context, health.kernel),
                  if (health.battery != null) ...[const SizedBox(height: 16), _buildBatteryCard(context, health.battery!)],
                  const SizedBox(height: 16),
                  _buildDisksCard(context, health.disks),
                  const SizedBox(height: 16),
                  _buildServicesCard(context, health.services),
                  const SizedBox(height: 16),
                  _buildSystemStatsCard(context, health),
                  const SizedBox(height: 16),
                  _buildLastCheckedInfo(context, health.lastCheck, service),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverallHealthCard(BuildContext context, SystemHealth health, SystemHealthService service) {
    final status = health.overallStatus;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Card(
      color: color.withAlpha(30),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 12),
            Text(
              _getStatusText(status),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(health.issueCount == 0 ? 'All systems operational' : '${health.issueCount} issue${health.issueCount > 1 ? 's' : ''} detected', style: Theme.of(context).textTheme.bodyLarge),
            // Show critical and warning issues
            if (health.issues.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...health.issues
                  .take(5)
                  .map(
                    (issue) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(_getStatusIcon(issue.status), size: 16, color: _getStatusColor(issue.status)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(issue.title, style: TextStyle(fontSize: 13, color: _getStatusColor(issue.status))),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (health.issues.length > 5) TextButton(onPressed: () => _showAllIssues(context, health), child: Text('View all ${health.issues.length} issues')),
            ],
            if (service.isChecking) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
          ],
        ),
      ),
    );
  }

  Widget _buildPackageUpdatesCard(BuildContext context, PackageUpdates packages, SystemHealthService service) {
    final status = packages.healthStatus;
    final color = _getStatusColor(status);

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.system_update, color: color, size: 32),
        title: const Text('Package Updates'),
        subtitle: Text(
          '${packages.totalUpdates} update${packages.totalUpdates != 1 ? 's' : ''} available'
          '${packages.securityUpdates > 0 ? ' (${packages.securityUpdates} security)' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(status), color: color, size: 20),
            const SizedBox(width: 8),
            if (!service.isChecking) IconButton(icon: const Icon(Icons.refresh), tooltip: 'Update package list (requires password)', onPressed: () => _updatePackageCache(context, service)),
          ],
        ),
        children: [
          if (packages.totalUpdates == 0)
            const Padding(padding: EdgeInsets.all(16), child: Text('System is up to date! ✨'))
          else ...[
            if (packages.securityUpdates > 0)
              ListTile(
                leading: const Icon(Icons.security, color: Colors.red),
                title: Text('${packages.securityUpdates} Security Updates'),
                subtitle: const Text('Update as soon as possible'),
                trailing: ElevatedButton(onPressed: () => _showUpdateCommand(context, service.packageManager), child: const Text('How to Update')),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Updates:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...packages.packages.take(10).map((pkg) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${pkg.split(' ').first}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    );
                  }),
                  if (packages.packages.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${packages.packages.length - 10} more',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKernelCard(BuildContext context, KernelInfo kernel) {
    final status = kernel.healthStatus;
    final color = _getStatusColor(status);

    return Card(
      child: ListTile(
        leading: Icon(Icons.developer_board, color: color, size: 32),
        title: const Text('Linux Kernel'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current: ${kernel.currentVersion}'),
            if (!kernel.isLatest) Text('Latest: ${kernel.latestAvailable}'),
            if (kernel.isLTS) const Text('LTS Version', style: TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Icon(kernel.isLatest ? Icons.check_circle : Icons.info, color: color),
      ),
    );
  }

  Widget _buildBatteryCard(BuildContext context, BatteryHealth battery) {
    final status = battery.healthStatus;
    final color = _getStatusColor(status);

    return Card(
      child: ExpansionTile(
        leading: Icon(battery.isCharging ? Icons.battery_charging_full : Icons.battery_std, color: color, size: 32),
        title: const Text('Battery Health'),
        subtitle: Text(
          '${battery.healthPercentage.toStringAsFixed(1)}% health • '
          '${battery.chargeLevel}% charged',
        ),
        trailing: Icon(_getStatusIcon(status), color: color, size: 20),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('Status', battery.status),
                _buildInfoRow('Charge Level', '${battery.chargeLevel}%'),
                _buildInfoRow('Health', '${battery.healthPercentage.toStringAsFixed(1)}%'),
                _buildInfoRow('Current Capacity', '${battery.currentCapacity} mAh'),
                _buildInfoRow('Design Capacity', '${battery.designCapacity} mAh'),
                _buildInfoRow('Cycle Count', '${battery.cycleCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisksCard(BuildContext context, List<DiskHealth> disks) {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.storage, color: _getStatusColor(disks.isEmpty ? HealthStatus.good : disks.map((d) => d.healthStatus).reduce((a, b) => a.index > b.index ? a : b)), size: 32),
        title: const Text('Disk Health'),
        subtitle: Text('${disks.length} disk${disks.length != 1 ? 's' : ''} monitored'),
        children: disks.map((disk) => _buildDiskTile(context, disk)).toList(),
      ),
    );
  }

  Widget _buildDiskTile(BuildContext context, DiskHealth disk) {
    final status = disk.healthStatus;
    final color = _getStatusColor(status);

    return ListTile(
      leading: Icon(Icons.disc_full, color: color),
      title: Text(disk.mountPoint),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(disk.device),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: disk.usagePercentage / 100, backgroundColor: Colors.grey.shade200, color: color),
          const SizedBox(height: 4),
          Text(
            '${_formatBytes(disk.usedSpace)} / ${_formatBytes(disk.totalSpace)} '
            '(${disk.usagePercentage.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 11),
          ),
          if (disk.temperature != null) Text('Temp: ${disk.temperature}°C', style: const TextStyle(fontSize: 11)),
        ],
      ),
      trailing: Icon(disk.smart ? Icons.check_circle : Icons.error, color: disk.smart ? Colors.green : Colors.red),
    );
  }

  Widget _buildServicesCard(BuildContext context, ServicesHealth services) {
    final status = services.healthStatus;
    final color = _getStatusColor(status);

    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.settings_applications, color: color, size: 32),
        title: const Text('System Services'),
        subtitle: Text(
          '${services.activeServices}/${services.totalServices} active'
          '${services.failedServices.isNotEmpty ? ' • ${services.failedServices.length} failed' : ''}',
        ),
        trailing: Icon(_getStatusIcon(status), color: color, size: 20),
        children: [
          if (services.failedServices.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('All services running normally ✅'))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Failed Services:', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red)),
                  const SizedBox(height: 8),
                  ...services.failedServices.map((service) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(service, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSystemStatsCard(BuildContext context, SystemHealth health) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Stats', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildInfoRow('CPU Temperature', '${health.cpuTemp.toStringAsFixed(1)}°C'),
            _buildInfoRow('Memory Usage', '${health.memoryUsage.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildLastCheckedInfo(BuildContext context, DateTime lastCheck, SystemHealthService service) {
    final now = DateTime.now();
    final diff = now.difference(lastCheck);
    String timeAgo;

    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Last checked: $timeAgo', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ElevatedButton.icon(
            onPressed: service.isChecking ? null : () => service.checkHealth(),
            icon: service.isChecking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Color _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Colors.green;
      case HealthStatus.good:
        return Colors.blue;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Icons.check_circle;
      case HealthStatus.good:
        return Icons.thumb_up;
      case HealthStatus.warning:
        return Icons.warning;
      case HealthStatus.critical:
        return Icons.error;
    }
  }

  String _getStatusText(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.warning:
        return 'Needs Attention';
      case HealthStatus.critical:
        return 'Critical';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showUpdateCommand(BuildContext context, PackageManager pm) {
    String command;
    switch (pm) {
      case PackageManager.apt:
        command = 'sudo apt update && sudo apt upgrade';
        break;
      case PackageManager.pacman:
        command = 'sudo pacman -Syu';
        break;
      case PackageManager.dnf:
        command = 'sudo dnf upgrade';
        break;
      case PackageManager.zypper:
        command = 'sudo zypper update';
        break;
      case PackageManager.nix:
        command = 'nix-channel --update && nix-env -u';
        break;
      default:
        command = 'Check your distribution documentation';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Run this command in your terminal:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(
                command,
                style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _updatePackageCache(BuildContext context, SystemHealthService service) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Package List'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will update your package manager\'s database.'),
            SizedBox(height: 12),
            Text('You will be prompted for your password (via pkexec).'),
            SizedBox(height: 12),
            Text('This does NOT install updates, only checks what\'s available.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Updating package list...'),
            SizedBox(height: 8),
            Text('You may see a password prompt', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );

    // Update package cache
    final success = await service.updatePackageCache();

    if (!context.mounted) return;
    Navigator.pop(context); // Close progress dialog

    // Show result
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Package list updated successfully!' : 'Failed to update package list. Check if pkexec is available.'), backgroundColor: success ? Colors.green : Colors.red));
  }

  void _showAllIssues(BuildContext context, SystemHealth health) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getStatusIcon(health.overallStatus), color: _getStatusColor(health.overallStatus)),
            const SizedBox(width: 12),
            const Text('System Issues'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: health.issues.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final issue = health.issues[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(issue.status).withAlpha(50),
                  child: Icon(_getStatusIcon(issue.status), color: _getStatusColor(issue.status), size: 20),
                ),
                title: Text(
                  issue.title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(issue.status)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(issue.description),
                    const SizedBox(height: 4),
                    Text(
                      issue.component,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (health.criticalIssues.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                // Could trigger specific actions here
              },
              child: const Text('View Solutions'),
            ),
        ],
      ),
    );
  }
}

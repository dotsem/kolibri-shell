import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/system.dart';

class SystemTab extends StatefulWidget {
  const SystemTab({super.key});

  @override
  State<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<SystemTab> {
  final SystemInfoService _systemInfoService = SystemInfoService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _systemInfoService,
      builder: (_, __) {
        final service = _systemInfoService;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final primaryColor = colorScheme.primary;
        final secondaryColor = colorScheme.secondary;
        final tertiaryColor = colorScheme.tertiary;
        final mutedColor = colorScheme.onSurfaceVariant;

        if (!service.initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'System',
                children: [
                  _InfoRow(label: 'Distribution', value: service.distroName),
                  _InfoRow(label: 'Uptime', value: _formatDuration(service.uptime)),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'CPU',
                children: [
                  _InfoRow(label: 'Model', value: service.cpuModel),
                  _InfoRow(label: 'Usage', value: _formatPercent(service.cpuUsage)),
                  if (service.cpuTemp > 0) _InfoRow(label: 'Temperature', value: '${service.cpuTemp.toStringAsFixed(1)} °C'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: _Sparkline(values: service.cpuHistory, color: primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _systemInfoService.setCpuDetailsExpanded(!service.cpuDetailsExpanded);
                      },
                      style: TextButton.styleFrom(foregroundColor: mutedColor),
                      icon: Icon(service.cpuDetailsExpanded ? Icons.expand_less : Icons.expand_more),
                      label: Text(service.cpuDetailsExpanded ? 'Hide per-core' : 'Show per-core'),
                    ),
                  ),
                  if (service.cpuDetailsExpanded)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 12.0;
                        final columns = constraints.maxWidth >= 420 ? 2 : 1;
                        final itemWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - spacing) / columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (final core in service.cpuCores)
                              SizedBox(
                                width: itemWidth,
                                child: _CpuCoreTile(core: core, usageColor: primaryColor, tempColor: tertiaryColor),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Memory',
                children: [
                  _InfoRow(label: 'Usage', value: '${_formatBytes(service.memoryUsed)} / ${_formatBytes(service.memoryTotal)}'),
                  _InfoRow(label: 'Utilization', value: _formatPercent(service.memoryUsedPercentage)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: _Sparkline(values: service.memoryHistory, color: secondaryColor),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Swap', value: '${_formatBytes(service.swapUsed)} / ${_formatBytes(service.swapTotal)}'),
                  _InfoRow(label: 'Swap Utilization', value: _formatPercent(service.swapUsedPercentage)),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'GPU',
                children: [
                  _InfoRow(label: 'Name', value: service.gpuName),
                  _InfoRow(label: 'Usage', value: _formatPercent(service.gpuUsage)),
                  if (service.gpuTemp > 0) _InfoRow(label: 'Temperature', value: '${service.gpuTemp.toStringAsFixed(1)} °C'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: _Sparkline(values: service.gpuHistory, color: tertiaryColor),
                  ),
                  if (service.gpuTempHistory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        height: 80,
                        child: _Sparkline(values: _normalizeTemperatures(service.gpuTempHistory), color: colorScheme.error),
                      ),
                    ),
                  if (service.gpuMemoryTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InfoRow(label: 'Memory', value: '${service.gpuMemoryUsed.toStringAsFixed(0)} / ${service.gpuMemoryTotal.toStringAsFixed(0)} MiB'),
                    ),
                ],
              ),
              if (service.availableDisks.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Disks',
                  trailing: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDialog<Set<String>>(
                        context: context,
                        builder: (context) => _DiskSelectionDialog(available: service.availableDisks, preselected: service.visibleDiskMounts),
                      );

                      if (selected != null) {
                        await _systemInfoService.setVisibleDisks(selected);
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: mutedColor),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Select'),
                  ),
                  children: [
                    if (service.disks.isEmpty) Text('No disks selected', style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
                    for (final disk in service.disks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              disk.mountPoint,
                              style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            _InfoRow(label: 'Filesystem', value: disk.filesystem),
                            _InfoRow(label: 'Usage', value: '${disk.usedGb.toStringAsFixed(2)} / ${disk.totalGb.toStringAsFixed(2)} GB (${_formatPercent(disk.usagePercent)})'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    final segments = <String>[];
    if (days > 0) segments.add('${days}d');
    if (hours > 0 || days > 0) segments.add('${hours}h');
    segments.add('${minutes}m');
    return segments.join(' ');
  }

  String _formatPercent(double fraction) {
    return _formatPercentStatic(fraction);
  }

  static String _formatPercentStatic(double fraction) {
    final percent = (fraction * 100).clamp(0, 100);
    if (percent < 10) {
      return '${percent.toStringAsFixed(1)}%';
    }
    return '${percent.toStringAsFixed(0)}%';
  }

  String _formatBytes(double kilobytes) {
    final double bytes = kilobytes * 1024;
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    double value = bytes;
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final precision = value < 10 ? 1 : 0;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }
}

List<double> _normalizeTemperatures(List<double> values) {
  if (values.isEmpty) return const <double>[];
  double maxValue = values.first;
  for (final value in values) {
    if (value > maxValue) {
      maxValue = value;
    }
  }
  maxValue = maxValue <= 0 ? 1 : maxValue;
  return values.map((value) => (value / maxValue).clamp(0.0, 1.0).toDouble()).toList(growable: false);
}

class _CpuCoreTile extends StatelessWidget {
  const _CpuCoreTile({required this.core, required this.usageColor, required this.tempColor});

  final CpuCoreUsage core;
  final Color usageColor;
  final Color tempColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.surfaceVariant.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(core.displayName, style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
              Text(
                _SystemTabState._formatPercentStatic(core.usage),
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: _Sparkline(values: core.history, color: usageColor),
          ),
          if (core.temperature != null && core.tempHistory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Temp', style: theme.textTheme.bodySmall?.copyWith(color: mutedColor)),
                Text(
                  '${core.temperature!.toStringAsFixed(1)} °C',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(
              height: 60,
              child: _Sparkline(values: _normalizeTemperatures(core.tempHistory), color: tempColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color),
      child: Container(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    if (values.isEmpty) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      canvas.drawPath(path, paint);
      return;
    }

    final maxPoints = math.min(values.length, 120);
    final startIndex = values.length - maxPoints;
    final clamped = values.sublist(startIndex);
    final maxIndex = clamped.length - 1;
    for (int i = 0; i < clamped.length; i++) {
      final x = size.width * (i / math.max(1, maxIndex));
      final y = size.height * (1 - clamped[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DiskSelectionDialog extends StatefulWidget {
  const _DiskSelectionDialog({required this.available, required this.preselected});

  final List<DiskUsage> available;
  final Set<String> preselected;

  @override
  State<_DiskSelectionDialog> createState() => _DiskSelectionDialogState();
}

class _DiskSelectionDialogState extends State<_DiskSelectionDialog> {
  late Set<String> _selected;
  late bool _showAll;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.preselected);
    _showAll = _selected.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text('Select disks', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              SwitchListTile.adaptive(
                value: _showAll,
                title: Text('Show all disks', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)),
                onChanged: (value) {
                  setState(() {
                    _showAll = value;
                    if (_showAll) {
                      _selected.clear();
                    } else if (_selected.isEmpty && widget.available.isNotEmpty) {
                      _selected.add(widget.available.first.mountPoint);
                    }
                  });
                },
              ),
              Divider(color: mutedColor.withOpacity(0.3)),
              for (final disk in widget.available)
                CheckboxListTile(
                  value: _showAll ? true : _selected.contains(disk.mountPoint),
                  onChanged: _showAll
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(disk.mountPoint);
                            } else {
                              _selected.remove(disk.mountPoint);
                              if (_selected.isEmpty) {
                                _showAll = true;
                              }
                            }
                          });
                        },
                  title: Text('${disk.mountPoint} (${disk.filesystem})', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface)),
                  subtitle: Text('${disk.usedGb.toStringAsFixed(1)} / ${disk.totalGb.toStringAsFixed(1)} GB', style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor)),
                  activeColor: colorScheme.primary,
                  checkColor: colorScheme.onPrimary,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_showAll ? <String>{} : _selected);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/network.dart';

class NetworkThroughputCard extends StatelessWidget {
  const NetworkThroughputCard({super.key, required this.networkService});

  final NetworkService networkService;

  @override
  Widget build(BuildContext context) {
    if (networkService.throughput.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            networkService.interfaces.any((iface) => iface.connected)
                ? 'Collecting throughput data...'
                : 'No active interfaces to monitor.',
          ),
        ),
      );
    }

    final chips = networkService.throughput.entries.map((entry) {
      final rx = _formatDataRate(entry.value.rxBytesPerSecond);
      final tx = _formatDataRate(entry.value.txBytesPerSecond);
      return Chip(
        label: Text('${entry.key}: ↓ $rx • ↑ $tx'),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Realtime Throughput',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDataRate(double bytesPerSecond) {
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    double value = bytesPerSecond;
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}

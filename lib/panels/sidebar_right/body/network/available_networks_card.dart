import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/network.dart';

class NetworkAvailableNetworksCard extends StatelessWidget {
  const NetworkAvailableNetworksCard({super.key, required this.networkService});

  final NetworkService networkService;

  @override
  Widget build(BuildContext context) {
    final networks = networkService.availableNetworks;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Networks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (networkService.scanning) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      onPressed: networkService.scanning ? null : networkService.scanForNetworks,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh networks',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (networks.isEmpty)
              const Text('No Wi-Fi networks found. Try refreshing or moving closer to the access point.')
            else
              ...networks.map((network) => _AvailableNetworkTile(networkService: networkService, network: network)).toList(),
          ],
        ),
      ),
    );
  }
}

class _AvailableNetworkTile extends StatelessWidget {
  const _AvailableNetworkTile({required this.networkService, required this.network});

  final NetworkService networkService;
  final AvailableWifiNetwork network;

  @override
  Widget build(BuildContext context) {
    final isConnecting = networkService.connectingSsid == network.ssid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(_wifiStrengthIcon(network.strength)),
        title: Text(network.ssid),
        subtitle: Text('${network.strength}% • ${network.requiresPassword ? 'Secured' : 'Open'}'),
        trailing: ElevatedButton(
          onPressed: isConnecting ? null : () => _connect(context),
          child: isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Connect'),
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    String password = '';
    if (network.requiresPassword) {
      final controller = TextEditingController();
      final result = await showDialog<String?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Connect to ${network.ssid}'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Connect'),
              ),
            ],
          );
        },
      );

      if (result == null || result.isEmpty) {
        return;
      }
      password = result;
    }

    final error = await networkService.connectToNetwork(network, password: password);

    if (context.mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${network.ssid}')),
        );
      }
    }
  }

  IconData _wifiStrengthIcon(int strength) {
    if (strength >= 80) return Icons.signal_wifi_4_bar_rounded;
    if (strength >= 60) return Icons.network_wifi_3_bar;
    if (strength >= 40) return Icons.network_wifi_2_bar;
    if (strength >= 20) return Icons.network_wifi_1_bar;
    return Icons.signal_wifi_0_bar;
  }
}

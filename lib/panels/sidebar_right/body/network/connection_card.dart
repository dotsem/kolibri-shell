import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/network.dart';

class NetworkConnectionCard extends StatelessWidget {
  const NetworkConnectionCard({super.key, required this.networkService});

  final NetworkService networkService;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    final ethernetInterfaces = networkService.interfaces
        .where((iface) => iface.type == NetworkInterfaceType.ethernet && iface.connected)
        .toList();

    if (ethernetInterfaces.isNotEmpty) {
      rows.addAll(ethernetInterfaces.map(
        (iface) => ListTile(
          leading: const Icon(Icons.lan, color: Colors.greenAccent),
          title: Text('Ethernet (${iface.name})'),
          subtitle: Text(iface.connectionName ?? 'Connected'),
        ),
      ));
    }

    if (networkService.wifiConnection != null) {
      final wifi = networkService.wifiConnection!;
      rows.add(
        ListTile(
          leading: Icon(
            _wifiStrengthIcon(wifi.strength),
            color: Colors.white,
          ),
          title: Text('Wi-Fi (${wifi.ssid})'),
          subtitle: Text('${wifi.strength}% • ${wifi.isSecure ? 'Secured' : 'Open'}'),
          trailing: TextButton(
            onPressed: networkService.connectingSsid == null ? networkService.disconnectWifi : null,
            child: const Text('Disconnect'),
          ),
        ),
      );
    } else if (networkService.hasWifi) {
      rows.add(
        ListTile(
          leading: const Icon(Icons.wifi_off, color: Colors.orange),
          title: const Text('Wi-Fi disconnected'),
          subtitle: const Text('Select a network below to connect'),
          trailing: IconButton(
            onPressed: networkService.scanning ? null : networkService.scanForNetworks,
            icon: networkService.scanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Scan for networks',
          ),
        ),
      );
    } else {
      rows.add(
        const ListTile(
          leading: Icon(Icons.wifi_off, color: Colors.grey),
          title: Text('Wi-Fi hardware unavailable'),
          subtitle: Text('Only wired networking is available on this device'),
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        const ListTile(
          leading: Icon(Icons.report_problem, color: Colors.redAccent),
          title: Text('No active network connections'),
          subtitle: Text('Check your cables or connect to a Wi-Fi network below'),
        ),
      );
    }

    if (networkService.errorMessage != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text(
            networkService.errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Active Connections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  static IconData _wifiStrengthIcon(int strength) {
    if (strength >= 80) return Icons.signal_wifi_4_bar_rounded;
    if (strength >= 60) return Icons.network_wifi_3_bar;
    if (strength >= 40) return Icons.network_wifi_2_bar;
    if (strength >= 20) return Icons.network_wifi_1_bar;
    return Icons.signal_wifi_0_bar;
  }
}

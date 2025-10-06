import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/network.dart';

class WifiIndicator extends StatefulWidget {
  const WifiIndicator({super.key});

  @override
  State<WifiIndicator> createState() => _WifiIndicatorState();
}

class _WifiIndicatorState extends State<WifiIndicator> {
  final NetworkService _networkService = NetworkService();

  @override
  void initState() {
    super.initState();
    _networkService.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _networkService,
      builder: (_, __) {
        final service = _networkService;

        if (service.ethernetConnected) {
          return const Icon(Icons.lan_rounded, color: Colors.lightGreenAccent);
        }

        if (service.hasWifi) {
          if (service.wifiConnection != null) {
            final strength = service.wifiConnection!.strength;
            return Icon(
              _wifiStrengthIcon(strength),
              color: Colors.white,
            );
          }

          if (service.scanning || service.availableNetworks.isNotEmpty) {
            return const Icon(Icons.wifi_find_rounded, color: Colors.blueAccent);
          }

          return const Icon(Icons.signal_wifi_off_rounded, color: Colors.orangeAccent);
        }

        return const Icon(Icons.signal_wifi_off_rounded, color: Colors.grey);
      },
    );
  }

  IconData _wifiStrengthIcon(int strength) {
    if (strength >= 80) return Icons.signal_wifi_4_bar_rounded;
    if (strength >= 60) return Icons.network_wifi_3_bar;
    if (strength >= 40) return Icons.network_wifi_2_bar;
    if (strength >= 20) return Icons.network_wifi_1_bar;
    return Icons.signal_wifi_0_bar_rounded;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:dbus_wifi/dbus_wifi.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/data.dart';
import 'package:hypr_flutter/services/network.dart';

enum NetworkState {
  connecteds0(icon: Icons.signal_wifi_0_bar_rounded, color: Colors.white),
  connecteds1(icon: Icons.network_wifi_1_bar, color: Colors.white),
  connecteds2(icon: Icons.network_wifi_2_bar, color: Colors.white),
  connecteds3(icon: Icons.network_wifi_3_bar, color: Colors.white),
  connecteds4(icon: Icons.signal_wifi_4_bar_rounded, color: Color.fromARGB(255, 9, 255, 0)),
  disconnected(icon: Icons.signal_wifi_off_rounded, color: Colors.red),
  ethernet(icon: Icons.lan_rounded, color: Colors.lime),
  searching(icon: Icons.wifi_find_rounded, color: Colors.blue);

  const NetworkState({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class WifiIndicator extends StatefulWidget {
  const WifiIndicator({super.key});

  @override
  State<WifiIndicator> createState() => _WifiIndicatorState();
}

class _WifiIndicatorState extends State<WifiIndicator> {
  NetworkManager networkManager = NetworkManager();
  NetworkState networkState = NetworkState.searching;
  bool? hasWifi;
  @override
  void initState() {
    super.initState();

    // wifi.hasWifiDevice.then((value) {
    //   hasWifi = value;
    //   setState(() {
    //     wifiIcon = hasWifi! ? Icons.wifi : Icons.wifi_off;
    //   });

    //   Timer.periodic(const Duration(seconds: 1), (timer) async {

    //   });

    //   wifi.getConnectionStatus().then((value) {
    //     print(value.toString());
    //   });

    //   wifi.search().then((value) {
    //     print(value.toString());
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: networkManager,
      builder: (_, __) {
        if (hasWifi ?? false) {
          if (networkManager.networkModel.connectionStatus == ConnectionStatus.connected) {
            if (networkManager.networkModel.ethernet) {
              networkState = NetworkState.ethernet;
            }
          }
        } else if (networkManager.networkModel.ethernet) {
          networkState = NetworkState.ethernet;
        } else {
          return Container();
        }
        return Icon(networkState.icon, color: networkState.color);
      },
    );
  }
}

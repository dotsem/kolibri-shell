import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/audio_tab.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/bluetooth/bluetooth_tab.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/network/network_tab.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/vpn/vpn_tab.dart';
import 'package:hypr_flutter/services/bluetooth.dart';
import 'package:hypr_flutter/services/network.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/system/system_tab.dart';
import 'package:hypr_flutter/services/vpn_service.dart';
import 'package:hypr_flutter/utils/settings_helper.dart';

class SidebarRightBody extends StatefulWidget {
  const SidebarRightBody({super.key});

  @override
  State<SidebarRightBody> createState() => SidebarRightBodyState();
}

class SidebarRightBodyState extends State<SidebarRightBody> {
  BluetoothService bluetoothService = BluetoothService();
  final NetworkService networkService = NetworkService();
  bool _showVpnTab = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final showVpn = await SettingsHelper.get<bool>(SettingsKeys.showVpnTab);
    if (mounted) {
      setState(() {
        _showVpnTab = showVpn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpnService = VpnService();

    return AnimatedBuilder(
      animation: Listenable.merge([bluetoothService, networkService, vpnService]),
      builder: (_, __) {
        int tabCount = 3; // Volume, Network, System
        if (bluetoothService.available) tabCount++;
        if (_showVpnTab) tabCount++;

        return DefaultTabController(
          length: tabCount,
          child: Expanded(
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Column(children: [Icon(Icons.volume_up), Text("Volume")]),
                    if (bluetoothService.available) Column(children: [Icon(Icons.bluetooth), Text("Bluetooth")]),
                    Column(children: [Icon(Icons.wifi), Text("Network")]),
                    if (_showVpnTab) Column(children: [Icon(Icons.vpn_lock), Text("VPN")]),
                    Column(children: [Icon(Icons.monitor_heart), Text("System")]),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      AudioTab(),
                      if (bluetoothService.available) BluetoothTab(bluetoothService: bluetoothService),
                      NetworkTab(networkService: networkService),
                      if (_showVpnTab) const VpnTab(),
                      const SystemTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

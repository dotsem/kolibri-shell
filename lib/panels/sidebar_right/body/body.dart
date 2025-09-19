import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/bluetooth_tab.dart';
import 'package:hypr_flutter/services/bluetooth.dart';

class SidebarRightBody extends StatefulWidget {
  const SidebarRightBody({super.key});

  @override
  State<SidebarRightBody> createState() => SidebarRightBodyState();
}

class SidebarRightBodyState extends State<SidebarRightBody> {
  BluetoothService bluetoothService = BluetoothService();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (_, __) {
        return DefaultTabController(
          length: bluetoothService.available ? 4 : 3,
          child: Expanded(
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Column(children: [Icon(Icons.volume_up), Text("Volume")]),
                    if (bluetoothService.available) Column(children: [Icon(Icons.bluetooth), Text("Bluetooth")]),
                    Column(children: [Icon(Icons.wifi), Text("Network")]),
                    Column(children: [Icon(Icons.monitor_heart), Text("System")]),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      Center(child: Text("Tab 1")),
                      if (bluetoothService.available) BluetoothTab(bluetoothService: bluetoothService),

                      Center(child: Text("Tab 2")),
                      Center(child: Text("Tab 3")),
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

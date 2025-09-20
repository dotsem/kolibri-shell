import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/bluetooth_list.dart';
import 'package:hypr_flutter/services/bluetooth.dart';

class BluetoothIcons {}

class BluetoothTab extends StatefulWidget {
  final BluetoothService bluetoothService;
  const BluetoothTab({super.key, required this.bluetoothService});

  @override
  State<BluetoothTab> createState() => _BluetoothTabState();
}

class _BluetoothTabState extends State<BluetoothTab> {
  bool isScanning = false;

  @override
  void initState() {
    super.initState();

    isScanning = widget.bluetoothService.adapter!.discovering;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.bluetoothService.adapter?.name ?? "unknown"),
                isScanning
                    ? ElevatedButton(
                        onPressed: () {
                          setState(() {
                            widget.bluetoothService.adapter!.stopDiscovery();
                            isScanning = true;
                          });
                        },
                        child: Text("Stop scanning"),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          setState(() {
                            widget.bluetoothService.adapter!.startDiscovery();
                            isScanning = false;
                          });
                        },
                        child: Text("Scan"),
                      ),
              ],
            ),
          ),
          Divider(color: Colors.grey[700], endIndent: 8, indent: 8),
          AnimatedBuilder(
            animation: widget.bluetoothService,
            builder: (_, __) {
              return Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      BluetoothList(itemBuilder: widget.bluetoothService.connectedDevices, title: "Connected"),
                      BluetoothList(itemBuilder: widget.bluetoothService.trustedDevices, title: "Trusted"),
                      BluetoothList(itemBuilder: widget.bluetoothService.discoveredDevices, title: "Discovered"),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

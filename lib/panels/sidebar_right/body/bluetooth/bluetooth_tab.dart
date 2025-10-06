import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/bluetooth/bluetooth_list.dart';
import 'package:hypr_flutter/services/bluetooth.dart';

class BluetoothIcons {}

class BluetoothTab extends StatefulWidget {
  final BluetoothService bluetoothService;
  const BluetoothTab({super.key, required this.bluetoothService});

  @override
  State<BluetoothTab> createState() => _BluetoothTabState();
}

class _BluetoothTabState extends State<BluetoothTab> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bluetoothService,
      builder: (_, __) {
        final service = widget.bluetoothService;
        final discovering = service.discovering;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(service.adapter?.name ?? "unknown"),
                    ElevatedButton(
                      onPressed: service.available
                          ? () {
                              if (discovering) {
                                service.stopDiscovery();
                              } else {
                                service.startDiscovery();
                              }
                            }
                          : null,
                      child: discovering
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text("Stop scanning"),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bluetooth_searching_rounded),
                                SizedBox(width: 8),
                                Text("Scan"),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[700], endIndent: 8, indent: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      BluetoothList(itemBuilder: service.connectedDevices, title: "Connected"),
                      BluetoothList(itemBuilder: service.trustedDevices, title: "Trusted"),
                      BluetoothList(itemBuilder: service.discoveredDevices, title: "Discovered"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

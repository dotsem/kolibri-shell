import 'package:flutter/material.dart';
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
    IconData getBluetoothIcon(String iconName) {
      switch (iconName) {
        case "audio-card":
          return Icons.speaker;
        case "audio-headset":
          return Icons.headphones;
        default:
          return Icons.device_unknown;
      }
    }

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
                widget.bluetoothService.adapter!.discovering
                    ? ElevatedButton(
                        onPressed: () {
                          widget.bluetoothService.adapter!.stopDiscovery();
                        },
                        child: Text("Stop scanning"),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          widget.bluetoothService.adapter!.startDiscovery();
                        },
                        child: Text("Scan"),
                      ),
              ],
            ),
          ),
          Divider(color: Colors.grey[700], endIndent: 8, indent: 8),
          Expanded(
            child: ListView.builder(
              itemBuilder: (_, index) {
                bool connected = widget.bluetoothService.devices[index].connected;
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Padding(padding: const EdgeInsets.only(right: 4), child: Icon(getBluetoothIcon(widget.bluetoothService.devices[index].icon), size: 24)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Text(widget.bluetoothService.devices[index].name, style: TextStyle(fontSize: 18))]),
                          Text(widget.bluetoothService.devices[index].address, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.scrim)),
                        ],
                      ),
                      Spacer(),
                      connected
                          ? ElevatedButton(
                              onPressed: () {
                                widget.bluetoothService.devices[index].disconnect();
                              },
                              child: Text("Disconnect"),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                widget.bluetoothService.devices[index].connect();
                              },
                              child: Text("Connect"),
                            ),
                    ],
                  ),
                );
              },
              itemCount: widget.bluetoothService.devices.length,
            ),
          ),
        ],
      ),
    );
  }
}

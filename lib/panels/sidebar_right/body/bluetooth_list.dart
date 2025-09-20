import 'package:bluez/bluez.dart';
import 'package:flutter/material.dart';

class BluetoothList extends StatefulWidget {
  final List<BlueZDevice> itemBuilder;
  final String title;
  const BluetoothList({super.key, required this.itemBuilder, required this.title});

  @override
  State<BluetoothList> createState() => _BluetoothListState();
}

class _BluetoothListState extends State<BluetoothList> {
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

  @override
  Widget build(BuildContext context) {
    if (widget.itemBuilder.isEmpty) {
      return Container();
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.title,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),

              itemCount: widget.itemBuilder.length,
              itemBuilder: (_, index) {
                BlueZDevice device = widget.itemBuilder[index];
                bool connected = device.connected;
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Padding(padding: const EdgeInsets.only(right: 4), child: Icon(getBluetoothIcon(device.icon), size: 24)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Text(device.name, style: TextStyle(fontSize: 18))]),
                              Text(device.address, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.scrim)),
                            ],
                          ),
                          Spacer(),
                          connected
                              ? ElevatedButton(
                                  onPressed: () {
                                    device.disconnect();
                                  },
                                  child: Text("Disconnect"),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    device.connect();
                                  },
                                  child: Text("Connect"),
                                ),
                        ],
                      ),
                      if (index < widget.itemBuilder.length - 1) Divider(color: Colors.grey[700], endIndent: 4, indent: 4),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

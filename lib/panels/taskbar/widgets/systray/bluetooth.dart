import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/bluetooth.dart';

class BluetoothIndicator extends StatefulWidget {
  const BluetoothIndicator({super.key});

  @override
  State<BluetoothIndicator> createState() => _BluetoothIndicatorState();
}

class _BluetoothIndicatorState extends State<BluetoothIndicator> {
  BluetoothService bluetoothService = BluetoothService();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (_, __) {
        if (!bluetoothService.available) {
          return Container();
        } else {
          return Icon(bluetoothService.connected ? Icons.bluetooth_connected : Icons.bluetooth, color: Colors.white);
        }
      },
    );
  }
}

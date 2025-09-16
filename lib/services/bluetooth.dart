import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();

  bool _connected = false;
  bool available = false;

  bool get connected => _connected;

  BlueZAdapter? adapter;
  List<BlueZDevice> devices = [];

  final bluetoothClient = BlueZClient();

  factory BluetoothService() => _instance;

  BluetoothService._internal() {
    print("Initializing bluetooth service");
    bluetoothClient.connect().then((_) {
      if (bluetoothClient.adapters.isEmpty) {
        available = false;
        return;
      } else {
        if (bluetoothClient.adapters.length > 1 && kDebugMode) {
          // ignore: avoid_print because hablaboblo
          print("Multiple adapters found: ${bluetoothClient.adapters.length}, taking the first one");
        }
        available = true;
        adapter = bluetoothClient.adapters.first;
      }
      for (BlueZDevice device in bluetoothClient.devices) {
        devices.add(device);
        if (device.connected) {
          _connected = true;
        }
      }
      notifyListeners();
    });
  }
}

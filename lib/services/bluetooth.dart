import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();

  bool _connected = false;
  bool available = false;

  bool get connected => _connected;

  BlueZAdapter? adapter;
  List<BlueZDevice> devices = [];
  List<BlueZDevice> connectedDevices = [];
  List<BlueZDevice> trustedDevices = [];
  List<BlueZDevice> discoveredDevices = [];

  final bluetoothClient = BlueZClient();

  factory BluetoothService() => _instance;

  BluetoothService._internal() {
    print("Initializing bluetooth service");
    try {
      bluetoothClient.connect().then((_) {
        if (bluetoothClient.adapters.isEmpty) {
          available = false;
          return;
        } else {
          if (bluetoothClient.adapters.length > 1 && kDebugMode) {
            // ignore: avoid_print because hablaboblo
            print(
              "Multiple adapters found: ${bluetoothClient.adapters.length}, taking the first one",
            );
          }
          available = true;
          adapter = bluetoothClient.adapters.first;
        }
        for (BlueZDevice device in bluetoothClient.devices) {
          if (device.connected) {
            connectedDevices.add(device);
          } else if (device.trusted) {
            trustedDevices.add(device);
          } else {
            discoveredDevices.add(device);
          }
          devices.add(device);
          if (device.connected) {
            _connected = true;
          }
        }
        notifyListeners();
      });
    } catch (e) {
      available = false;
    }
  }
}

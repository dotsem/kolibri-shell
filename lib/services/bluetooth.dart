import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();

  bool _connected = false;
  bool available = false;

  bool get connected => _connected;
  Timer? _discoveryTimeout;

  BlueZAdapter? adapter;
  final List<BlueZDevice> devices = [];
  final List<BlueZDevice> connectedDevices = [];
  final List<BlueZDevice> trustedDevices = [];
  final List<BlueZDevice> discoveredDevices = [];
  bool _discovering = false;

  bool get discovering => _discovering;

  final bluetoothClient = BlueZClient();
  final Map<String, StreamSubscription<List<String>>> _deviceSubscriptions = {};

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
            print("Multiple adapters found: ${bluetoothClient.adapters.length}, taking the first one");
          }
          available = true;
          adapter = bluetoothClient.adapters.first;
        }
        _loadInitialDevices();
        _listenForDeviceEvents();
        adapter?.propertiesChanged.listen((_) {
          _updateDiscoveryState();
        });
        _updateDiscoveryState();
        notifyListeners();
      });
    } catch (e) {
      available = false;
    }
  }

  void _loadInitialDevices() {
    for (final subscription in _deviceSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _deviceSubscriptions.clear();

    connectedDevices.clear();
    trustedDevices.clear();
    discoveredDevices.clear();
    devices.clear();

    for (final device in bluetoothClient.devices) {
      devices.add(device);
      _registerDevice(device);
    }

    _refreshDeviceLists();
  }

  void _listenForDeviceEvents() {
    bluetoothClient.deviceAdded.listen((device) {
      final key = device.path.value;
      if (devices.any((d) => d.path.value == key)) return;
      devices.add(device);
      _registerDevice(device);
      _refreshDeviceLists();
      notifyListeners();
    });

    bluetoothClient.deviceRemoved.listen((device) {
      final key = device.path.value;
      devices.removeWhere((d) => d.path.value == key);
      final subscription = _deviceSubscriptions.remove(key);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      _refreshDeviceLists();
      notifyListeners();
    });
  }

  void _refreshDeviceLists() {
    connectedDevices.clear();
    trustedDevices.clear();
    discoveredDevices.clear();

    for (final device in devices) {
      _categorizeDevice(device);
    }

    _connected = connectedDevices.isNotEmpty;
  }

  void _categorizeDevice(BlueZDevice device) {
    if (!_shouldIncludeDevice(device)) {
      return;
    }
    if (device.connected) {
      connectedDevices.add(device);
    } else if (device.trusted) {
      trustedDevices.add(device);
    } else if (device.name.isNotEmpty) {
      discoveredDevices.add(device);
    }
  }

  bool _shouldIncludeDevice(BlueZDevice device) {
    final name = device.name.trim();
    final alias = device.alias.trim();
    final displayName = name.isNotEmpty ? name : alias;
    if (displayName.isEmpty) {
      return false;
    }
    final normalized = displayName.toLowerCase();
    if (normalized == 'unknown' || normalized == 'unnamed' || normalized == 'device') {
      return false;
    }
    final address = device.address.trim();
    if (address.isNotEmpty) {
      final normalizedDisplay = displayName.replaceAll(':', '').toUpperCase();
      final normalizedAddress = address.replaceAll(':', '').toUpperCase();
      if (normalizedDisplay == normalizedAddress) {
        return false;
      }
    }
    if (name.toLowerCase() == 'unknown' && alias.toLowerCase() == 'unknown') {
      return false;
    }
    return true;
  }

  void _updateDiscoveryState() {
    final discoveringNow = adapter?.discovering ?? false;
    if (_discovering != discoveringNow) {
      _discovering = discoveringNow;
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    if (adapter == null) return;
    if (!_discovering) {
      _discovering = true;
      notifyListeners();
    }
    try {
      await adapter!.startDiscovery();
      if (adapter!.discovering) {
        _discoveryTimeout = Timer(const Duration(seconds: 30), () {
          if (adapter!.discovering) {
            stopDiscovery();
          }
        });
      }
    } finally {
      _updateDiscoveryState();
    }
  }

  Future<void> stopDiscovery() async {
    if (adapter == null) return;
    if (_discovering) {
      _discovering = false;
      _discoveryTimeout?.cancel();
      notifyListeners();
    }
    try {
      await adapter!.stopDiscovery();
    } finally {
      _updateDiscoveryState();
    }
  }

  void _registerDevice(BlueZDevice device) {
    final key = device.path.value;
    if (_deviceSubscriptions.containsKey(key)) {
      return;
    }
    _deviceSubscriptions[key] = device.propertiesChanged.listen((_) {
      _refreshDeviceLists();
      notifyListeners();
    });
  }
}

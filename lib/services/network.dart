import 'dart:async';
import 'dart:io';

import 'package:dbus_wifi/dbus_wifi.dart';
import 'package:dbus_wifi/models/wifi_network.dart';
import 'package:flutter/foundation.dart';

enum NetworkInterfaceType { ethernet, wifi, loopback, other }

class NetworkInterfaceStatus {
  NetworkInterfaceStatus({
    required this.name,
    required this.type,
    required this.state,
    this.connectionName,
  });

  final String name;
  final NetworkInterfaceType type;
  final String state;
  final String? connectionName;

  bool get connected => state == 'connected';
}

class InterfaceThroughput {
  InterfaceThroughput({
    required this.rxBytesPerSecond,
    required this.txBytesPerSecond,
  });

  final double rxBytesPerSecond;
  final double txBytesPerSecond;

  bool get hasSample => rxBytesPerSecond > 0 || txBytesPerSecond > 0;
}

class WifiConnectionInfo {
  WifiConnectionInfo({
    required this.ssid,
    required this.strength,
    required this.security,
    this.connectionName,
  });

  final String ssid;
  final int strength;
  final String security;
  final String? connectionName;

  bool get isSecure => security != 'none';

  WifiConnectionInfo copyWith({String? connectionName, int? strength}) {
    return WifiConnectionInfo(
      ssid: ssid,
      strength: strength ?? this.strength,
      security: security,
      connectionName: connectionName ?? this.connectionName,
    );
  }
}

class AvailableWifiNetwork {
  AvailableWifiNetwork(this.network);

  final WifiNetwork network;

  String get ssid => network.ssid;
  int get strength => network.strength;
  String get security => network.security;
  bool get requiresPassword => security != 'none';
}

class NetworkService extends ChangeNotifier {
  factory NetworkService() => _instance;

  NetworkService._internal() {
    _initialise();
  }

  static final NetworkService _instance = NetworkService._internal();

  final DbusWifi _wifi = DbusWifi();
  final Map<String, int> _previousRxBytes = {};
  final Map<String, int> _previousTxBytes = {};

  Timer? _pollTimer;
  DateTime? _lastThroughputSample;
  DateTime? _lastScanTime;
  bool _refreshing = false;

  bool hasWifi = false;
  bool ethernetConnected = false;
  WifiConnectionInfo? wifiConnection;
  List<NetworkInterfaceStatus> interfaces = [];
  Map<String, InterfaceThroughput> throughput = {};
  List<AvailableWifiNetwork> availableNetworks = [];
  bool scanning = false;
  String? errorMessage;
  String? connectingSsid;

  bool get wifiConnected => wifiConnection != null;

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _refreshConnections();
      await _updateThroughput();
      final shouldAutoScan = hasWifi && !wifiConnected && !ethernetConnected && !scanning;
      if (shouldAutoScan) {
        final now = DateTime.now();
        if (_lastScanTime == null || now.difference(_lastScanTime!) > const Duration(seconds: 20)) {
          await scanForNetworks();
        }
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> scanForNetworks() async {
    if (!hasWifi || scanning) return;

    scanning = true;
    errorMessage = null;
    notifyListeners();

    try {
      _lastScanTime = DateTime.now();
      final results = await _wifi.search(timeout: const Duration(seconds: 3));

      final Map<String, WifiNetwork> strongestPerSsid = {};
      for (final network in results) {
        final ssid = network.ssid.trim();
        if (ssid.isEmpty) continue;
        final current = strongestPerSsid[ssid];
        if (current == null || network.strength > current.strength) {
          strongestPerSsid[ssid] = network;
        }
      }

      final sorted = strongestPerSsid.values
          .map(AvailableWifiNetwork.new)
          .toList()
        ..sort((a, b) => b.strength.compareTo(a.strength));

      availableNetworks = sorted;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<String?> connectToNetwork(AvailableWifiNetwork network, {String password = ''}) async {
    if (!hasWifi) {
      return 'Wi-Fi hardware not available on this device.';
    }

    connectingSsid = network.ssid;
    errorMessage = null;
    notifyListeners();

    try {
      await _wifi.connect(network.network, password);
      await Future<void>.delayed(const Duration(seconds: 1));
      await refresh();
      return null;
    } catch (e) {
      errorMessage = e.toString();
      return errorMessage;
    } finally {
      connectingSsid = null;
      notifyListeners();
    }
  }

  Future<void> disconnectWifi() async {
    if (!hasWifi) return;
    try {
      await _wifi.disconnect();
      await refresh();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _initialise() async {
    try {
      hasWifi = await _wifi.hasWifiDevice;
    } catch (_) {
      hasWifi = false;
    }

    await refresh();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // ignore: discarded_futures
      refresh();
    });
  }

  Future<void> _refreshConnections() async {
    try {
      final result = await Process.run(
        'nmcli',
        ['-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'device'],
      );

      if (result.exitCode != 0) {
        errorMessage = result.stderr.toString().trim().isEmpty
            ? 'Failed to query network interfaces (nmcli exit code ${result.exitCode}).'
            : result.stderr.toString();
        interfaces = [];
        ethernetConnected = false;
        wifiConnection = null;
        return;
      }

      final List<NetworkInterfaceStatus> parsed = [];
      bool ethernet = false;
      bool wifi = false;
      String? wifiConnectionName;

      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        for (final rawLine in output.split('\n')) {
          if (rawLine.trim().isEmpty) continue;
          final segments = rawLine.split(':');
          if (segments.length < 3) continue;

          final device = segments[0];
          final type = _parseInterfaceType(segments[1]);
          final state = segments[2];
          final connectionName = segments.length > 3 && segments[3].trim().isNotEmpty ? segments[3].trim() : null;

          final status = NetworkInterfaceStatus(
            name: device,
            type: type,
            state: state,
            connectionName: connectionName,
          );

          parsed.add(status);

          if (type == NetworkInterfaceType.ethernet && status.connected) {
            ethernet = true;
          }

          if (type == NetworkInterfaceType.wifi && status.connected) {
            wifi = true;
            wifiConnectionName = connectionName;
          }
        }
      }

      interfaces = parsed;
      ethernetConnected = ethernet;

      if (wifi) {
        await _updateWifiConnection(connectionName: wifiConnectionName);
      } else {
        wifiConnection = null;
      }
    } on ProcessException catch (e) {
      errorMessage = 'Failed to execute nmcli: ${e.message}';
      interfaces = [];
      ethernetConnected = false;
      wifiConnection = null;
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  Future<void> _updateWifiConnection({String? connectionName}) async {
    try {
      final status = await _wifi.getConnectionStatus();
      if (status['status'] == ConnectionStatus.connected && status['network'] is WifiNetwork) {
        final wifiNetwork = status['network'] as WifiNetwork;
        wifiConnection = WifiConnectionInfo(
          ssid: wifiNetwork.ssid,
          strength: wifiNetwork.strength,
          security: wifiNetwork.security,
          connectionName: connectionName ?? wifiNetwork.ssid,
        );
      } else {
        wifiConnection = null;
      }
    } catch (e) {
      errorMessage = e.toString();
      wifiConnection = null;
    }
  }

  Future<void> _updateThroughput() async {
    final now = DateTime.now();
    final elapsed = _lastThroughputSample == null
        ? 0.0
        : now.difference(_lastThroughputSample!).inMilliseconds / 1000.0;

    final Map<String, InterfaceThroughput> updated = {};

    final activeInterfaces = interfaces.where(
      (iface) => iface.connected && (iface.type == NetworkInterfaceType.ethernet || iface.type == NetworkInterfaceType.wifi),
    );

    for (final iface in activeInterfaces) {
      final rx = await _readInterfaceBytes(iface.name, 'rx_bytes');
      final tx = await _readInterfaceBytes(iface.name, 'tx_bytes');
      if (rx == null || tx == null) {
        continue;
      }

      double rxRate = 0;
      double txRate = 0;

      if (_lastThroughputSample != null && elapsed > 0) {
        final previousRx = _previousRxBytes[iface.name];
        final previousTx = _previousTxBytes[iface.name];

        if (previousRx != null) {
          rxRate = (rx - previousRx) / elapsed;
          if (rxRate < 0) rxRate = 0;
        }

        if (previousTx != null) {
          txRate = (tx - previousTx) / elapsed;
          if (txRate < 0) txRate = 0;
        }
      }

      updated[iface.name] = InterfaceThroughput(
        rxBytesPerSecond: rxRate,
        txBytesPerSecond: txRate,
      );

      _previousRxBytes[iface.name] = rx;
      _previousTxBytes[iface.name] = tx;
    }

    _lastThroughputSample = now;
    throughput = updated;
  }

  Future<int?> _readInterfaceBytes(String interface, String stat) async {
    try {
      final path = '/sys/class/net/$interface/statistics/$stat';
      final contents = await File(path).readAsString();
      return int.tryParse(contents.trim());
    } catch (_) {
      return null;
    }
  }

  NetworkInterfaceType _parseInterfaceType(String raw) {
    switch (raw) {
      case 'ethernet':
        return NetworkInterfaceType.ethernet;
      case 'wifi':
        return NetworkInterfaceType.wifi;
      case 'loopback':
        return NetworkInterfaceType.loopback;
      default:
        return NetworkInterfaceType.other;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

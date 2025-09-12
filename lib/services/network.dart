import 'dart:io';

class NetworkService {
  bool wifi = false;
  bool ethernet = false;
  int updateInterval = 1000; // ms
  String networkName = "";
  int networkStrength = 0;

  /// Returns a material symbol string representing the current state
  String get materialSymbol {
    if (ethernet) return "lan";
    if (networkName.isNotEmpty && networkName != "lo") {
      if (networkStrength > 80) return "signal_wifi_4_bar";
      if (networkStrength > 60) return "network_wifi_3_bar";
      if (networkStrength > 40) return "network_wifi_2_bar";
      if (networkStrength > 20) return "network_wifi_1_bar";
      return "signal_wifi_0_bar";
    }
    return "signal_wifi_off";
  }

  /// Update all network state values
  Future<void> update() async {
    await _updateConnectionType();
    await _updateNetworkName();
    await _updateNetworkStrength();
  }

  Future<void> _updateConnectionType() async {
    try {
      final result = await Process.run('sh', ['-c', 'nmcli -t -f NAME,TYPE,DEVICE c show --active']);
      final lines = result.stdout.toString().trim().split('\n');
      bool hasEthernet = false;
      bool hasWifi = false;

      for (final line in lines) {
        if (line.contains("ethernet")) {
          hasEthernet = true;
        } else if (line.contains("wireless")) {
          hasWifi = true;
        }
      }
      ethernet = hasEthernet;
      wifi = hasWifi;
    } catch (e) {
      stderr.writeln("Connection type error: $e");
    }
  }

  Future<void> _updateNetworkName() async {
    try {
      final result = await Process.run('sh', ['-c', 'nmcli -t -f NAME c show --active | head -1']);
      networkName = result.stdout.toString().trim();
    } catch (e) {
      stderr.writeln("Network name error: $e");
    }
  }

  Future<void> _updateNetworkStrength() async {
    try {
      final result = await Process.run('sh', ['-c', "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print \$2}}'"]);
      final data = result.stdout.toString().trim();
      networkStrength = int.tryParse(data) ?? 0;
    } catch (e) {
      stderr.writeln("Network strength error: $e");
    }
  }
}

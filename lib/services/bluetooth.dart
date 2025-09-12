import 'dart:io';

class BluetoothService {
  Future<String> getDeviceNameAndAddress() async {
    try {
      final result = await Process.run('bash', ['-c', "bluetoothctl info | awk -F': ' '/Name: /{name=\$2} /Device /{addr=\$2} END{print name\":\"addr}'"]);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Device name/address error: $e';
    }
  }

  Future<String> getTop10DevicesByConnection() async {
    try {
      const command = '''
      bluetoothctl devices | grep "^Device" | while read -r _ mac name; do 
        connected=\$(bluetoothctl info "\$mac" | grep -q "Connected: yes" && echo 1 || echo 0); 
        echo "\${name}@\${connected}"; 
      done | sort -t@ -k2 -r | head -n 10 | paste -sd "|" -
      ''';

      final result = await Process.run('bash', ['-c', command]);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Top 10 devices error: $e';
    }
  }

  Future<String> isAnyDeviceConnected() async {
    try {
      final result = await Process.run('bash', ['-c', "bluetoothctl info | grep -q 'Connected: yes' && echo 1 || echo 0"]);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Connection status error: $e';
    }
  }
}

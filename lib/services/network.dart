import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus_wifi/dbus_wifi.dart';
import 'package:dbus_wifi/interfaces/nm_settings_remote_object.dart';
import 'package:flutter/foundation.dart';

Future<bool> isEthernetActiveConnection() async {
  String result = (await Process.run("ip", ["route", "get", "1.1.1.1"])).stdout.toString();
  return (result.split(" ")[4].contains("en"));
}

class NetworkManager extends ChangeNotifier {
  static final NetworkManager _instance = NetworkManager._internal();
  NetworkModel networkModel = NetworkModel(ConnectionStatus.disconnected, '', 0);

  factory NetworkManager() => _instance;

  DbusWifi wifi = DbusWifi();

  NetworkManager._internal() {
    wifi.hasWifiDevice.then((value) {
      if (value) {
        Timer.periodic(Duration(seconds: 1), (_) {
          wifi.getConnectionStatus().then((value) {
            // print(value);
            networkModel = NetworkModel(
              value['status'],
              value['network'].ssid,
              value['network'].strength,
            );
            notifyListeners();
          });
        });
      }
    });
  }
}

class NetworkModel {
  ConnectionStatus connectionStatus;
  String? ssid;
  int? strength;
  String? security;
  bool ethernet = false;
  bool isConnected() => connectionStatus == ConnectionStatus.connected;

  NetworkModel(this.connectionStatus, this.ssid, this.strength) {
    isEthernetActiveConnection().then((value) => ethernet = value);
  }

  NetworkModel.fromJson(Map<String, dynamic> json)
    : connectionStatus = ConnectionStatus.values[json['status']],
      ssid = json['SSID'],
      strength = json['Strength'];
}

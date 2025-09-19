import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/services.dart';

class ShellCommunication {
  static MethodChannel? _channel;

  static Future<MethodChannel> get instance async {
    if (_channel == null) {
      // Create the shared channel only once
      await FlLinuxWindowManager.instance.createSharedMethodChannel(channelName: "shell_communication", shareWithWindowId: "main", windowId: "main");

      _channel = const MethodChannel('shell_communication');
    }
    return _channel!;
  }
}

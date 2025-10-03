import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/services.dart';

class ShellCommunication {
  static MethodChannel? _channel;

  static Future<MethodChannel> instance({required String shareWithWindowId, required String windowId}) async {
    if (_channel == null) {
      print("Creating shell communication channel with: $shareWithWindowId | $windowId");
      await FlLinuxWindowManager.instance.createSharedMethodChannel(channelName: "shell_communication", shareWithWindowId: shareWithWindowId, windowId: windowId);

      _channel = const MethodChannel("shell_communication");
    }
    return _channel!;
  }
}

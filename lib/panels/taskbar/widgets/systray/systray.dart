import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/audio.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/bluetooth.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/wifi.dart';

class SystemTrayWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: AudioIndicator()),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: WifiIndicator()),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: BluetoothIndicator()),
        ],
      ),
    );
  }
}

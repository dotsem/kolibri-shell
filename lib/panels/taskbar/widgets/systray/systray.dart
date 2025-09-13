import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/systray/clock.dart';
import 'package:hypr_flutter/services/clock.dart';

class SystemTrayWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputRegion(
            child: IconButton(
              icon: Icon(Icons.wifi, color: Colors.white, size: 16),
              onPressed: () => print("WiFi clicked"),
            ),
          ),
          InputRegion(
            child: IconButton(
              icon: Icon(Icons.volume_up, color: Colors.white, size: 16),
              onPressed: () => print("Volume clicked"),
            ),
          ),
          InputRegion(
            child: IconButton(
              icon: Icon(Icons.battery_full, color: Colors.white, size: 16),
              onPressed: () => print("Battery clicked"),
            ),
          ),
          SizedBox(width: 8),
          Clock(),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}

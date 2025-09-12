import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';

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
          Text(DateTime.now().toString().substring(11, 16), style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(width: 8),
        ],
      ),
    );
  }
}

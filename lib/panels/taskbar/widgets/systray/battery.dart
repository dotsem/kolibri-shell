import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/widgets/animated/slide_fade_transition.dart';
import 'package:percent_indicator/flutter_percent_indicator.dart';

enum BatteryStateEnhanced {
  unknown(Icons.battery_unknown_rounded, Colors.purple),
  critical(Icons.battery_alert_rounded, Colors.red),
  low(Icons.battery_0_bar_rounded, Colors.orange),
  s1(Icons.battery_1_bar_rounded, Colors.yellow),
  s2(Icons.battery_2_bar_rounded, Colors.white),
  s3(Icons.battery_3_bar_rounded, Colors.white),
  s4(Icons.battery_4_bar_rounded, Colors.white),
  s5(Icons.battery_5_bar_rounded, Colors.white),
  s6(Icons.battery_6_bar_rounded, Colors.white),
  full(Icons.battery_full_rounded, Color.fromARGB(255, 9, 255, 0)),
  charging(Icons.battery_charging_full_rounded, Colors.blue),
  connectedNotCharging(Icons.battery_alert_rounded, Colors.purple);

  const BatteryStateEnhanced(this.icon, this.color);
  final IconData icon;
  final Color color;
}

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({super.key});

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  Battery battery = Battery();
  int batteryLevel = 0;
  BatteryState batteryState = BatteryState.unknown;
  IconData batteryIcon = Icons.battery_unknown_rounded;
  Color batteryColor = Colors.white;

  @override
  void initState() {
    super.initState();
    battery.onBatteryStateChanged.listen((event) async => getInternalBatteryState());

    battery.batteryLevel.then((value) {
      setState(() {
        batteryLevel = value;
      });
      getInternalBatteryState();
    });

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      batteryLevel = await battery.batteryLevel;

      setState(() {
        batteryLevel = batteryLevel;
      });
    });
  }

  void getInternalBatteryState() async {
    batteryState = await battery.batteryState;
    print(batteryState.toString());

    setState(() {
      BatteryStateEnhanced batteryStateEnhanced = getBatteryState();
      print(batteryStateEnhanced.toString());
      batteryIcon = batteryStateEnhanced.icon;
      batteryColor = batteryStateEnhanced.color;
    });
  }

  BatteryStateEnhanced getBatteryState() {
    if (batteryState == BatteryState.discharging) {
      switch (batteryLevel) {
        case < 5:
          return BatteryStateEnhanced.critical;
        case < 10:
          return BatteryStateEnhanced.low;
        case < 20:
          return BatteryStateEnhanced.s1;
        case < 30:
          return BatteryStateEnhanced.s2;
        case < 45:
          return BatteryStateEnhanced.s3;
        case < 60:
          return BatteryStateEnhanced.s4;
        case < 75:
          return BatteryStateEnhanced.s5;
        case < 85:
          return BatteryStateEnhanced.s6;
        case > 95:
          return BatteryStateEnhanced.full;
        default:
          return BatteryStateEnhanced.s6;
      }
    } else if (batteryState == BatteryState.charging) {
      return BatteryStateEnhanced.charging;
    } else if (batteryState == BatteryState.full) {
      return BatteryStateEnhanced.full;
    } else if (batteryState == BatteryState.connectedNotCharging) {
      return BatteryStateEnhanced.connectedNotCharging;
    }
    return BatteryStateEnhanced.unknown;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SlideFadeTransition(
          visible: batteryState == BatteryState.charging,
          direction: SlideDirection.right,
          child: Icon(Icons.bolt_rounded, color: batteryColor),
        ),
        Text("$batteryLevel%", style: TextStyle(color: batteryColor)),

        SizedBox(
          height: 40,
          width: 40,
          child: CircularPercentIndicator(
            radius: 15,
            lineWidth: 2,
            percent: batteryLevel / 100,
            center: Icon(batteryIcon, size: 22, color: batteryColor),
            backgroundColor: batteryColor.withAlpha(100),

            progressBorderColor: batteryColor,
            progressColor: batteryColor,
          ),
        ),
      ],
    );
  }
}

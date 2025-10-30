import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/clock.dart';

class Clock extends StatefulWidget {
  const Clock({super.key});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  late ClockService _clockService;

  @override
  void initState() {
    super.initState();
    _clockService = ClockService();
    _clockService.addListener(_onClockUpdate);
    print("Clock widget: Listening to ClockService in this isolate");
  }

  @override
  void dispose() {
    _clockService.removeListener(_onClockUpdate);
    super.dispose();
  }

  void _onClockUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _clockService.now.date,
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.scrim),
        ),
        Text(_clockService.now.time),
      ],
    );
  }
}

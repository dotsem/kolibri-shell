import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/clock.dart';

class Clock extends StatelessWidget {
  Clock({super.key});

  final clock = ClockService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (_, __) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(clock.now.time),
            Text(
              clock.now.date,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.scrim),
            ),
          ],
        );
      },
    );
  }
}

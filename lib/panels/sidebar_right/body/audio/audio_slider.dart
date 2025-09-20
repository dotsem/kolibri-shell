import 'package:flutter/material.dart';

typedef OnVolumeChangeCallback = void Function(double volume);
typedef OnMuteCallback = void Function(bool muted);

class AudioSlider extends StatelessWidget {
  final double value;
  final OnVolumeChangeCallback onVolumeChange;
  final bool muted;
  final OnMuteCallback onMute;
  final String identifier;
  const AudioSlider({super.key, required this.value, required this.onVolumeChange, required this.muted, required this.onMute, required this.identifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            onMute(!muted);
          },
          icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
        ),
        Slider(
          value: value,
          onChanged: (value) {
            onVolumeChange(value);
          },
        ),
        Radio(value: identifier),
      ],
    );
  }
}

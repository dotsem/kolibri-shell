import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/music.dart';

typedef MusicSliderCallback = void Function(double value);

class MusicSlider extends StatelessWidget {
  final MusicPlayer playerData;
  final MusicSliderCallback onChanged;

  const MusicSlider({super.key, required this.playerData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: SliderComponentShape.noThumb,
        trackHeight: 4,
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: SliderTheme.of(context).activeTrackColor,
        inactiveTrackColor: SliderTheme.of(context).inactiveTrackColor,
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: playerData.position.toDouble().clamp(0, playerData.length.toDouble()),
        max: playerData.length.toDouble(),
        onChanged: onChanged,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/music.dart';

class MusicInfo extends StatelessWidget {
  final MusicPlayer playerData;
  const MusicInfo({super.key, required this.playerData});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24, child: Text("${playerData.title} ° ${playerData.artist}", maxLines: 1, overflow: TextOverflow.ellipsis)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: SliderComponentShape.noThumb,
                trackHeight: 4,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: SliderTheme.of(context).activeTrackColor,
                inactiveTrackColor: SliderTheme.of(context).inactiveTrackColor,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(value: playerData.position.toDouble().clamp(0, playerData.length.toDouble()), max: playerData.length.toDouble(), onChanged: (value) {}),
            ),
          ],
        ),
      ),
    );
  }
}

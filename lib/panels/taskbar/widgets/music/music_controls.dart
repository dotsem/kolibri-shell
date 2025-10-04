import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/music.dart';

typedef MusicInfoCallback = void Function(double value);

class MusicControls extends StatelessWidget {
  final VoidCallback updatePlayerData;
  final MusicPlayer playerData;
  final MusicInfoCallback positionChanged;
  const MusicControls({
    super.key,
    required this.playerData,
    required this.updatePlayerData,
    required this.positionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,

                  constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                  onPressed: () async {
                    await playerData.previous();
                    updatePlayerData();
                  },
                  icon: Icon(Icons.skip_previous),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                  child: IconButton(
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                    onPressed: () async {
                      await (playerData.isPlaying ? playerData.pause() : playerData.play());
                      updatePlayerData();
                    },
                    icon: Icon(playerData.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                IconButton(
                  iconSize: 24,
                  padding: EdgeInsets.zero,

                  constraints: BoxConstraints(maxWidth: 32, maxHeight: 32),
                  onPressed: () async {
                    await playerData.next();
                    updatePlayerData();
                  },
                  icon: Icon(Icons.skip_next),
                ),
              ],
            ),
            SliderTheme(
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
                onChanged: positionChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/music/music_slider.dart';
import 'package:hypr_flutter/services/music.dart';

class MusicInfo extends StatelessWidget {
  final MusicPlayer playerData;
  final MusicSliderCallback onSeek;

  const MusicInfo({super.key, required this.playerData, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: Text(
                "${playerData.title} · ${playerData.artist.join(' · ')}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontWeight: FontWeight.w600),
              ),
            ),
            MusicSlider(playerData: playerData, onChanged: onSeek),
          ],
        ),
      ),
    );
  }
}

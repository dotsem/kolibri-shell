import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/music.dart';

class MusicPlayerWidget extends StatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicService musicService = MusicService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, child) {
        final playerData = musicService.playerData;

        if (playerData == null) {
          return Container();
        }

        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: playerData.art!, fit: BoxFit.cover),
          ),
          child: null /* add child content here */,
        );
      },
    );
  }
}

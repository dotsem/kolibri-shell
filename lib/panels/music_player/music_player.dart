import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/services/music.dart';
import 'package:hypr_flutter/window_ids.dart';
import 'package:palette_generator/palette_generator.dart';

class MusicPlayerWidget extends StatefulWidget {
  const MusicPlayerWidget({super.key});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget> {
  final MusicService musicService = MusicService();

  Color? dominantColor;
  Color? contrastColor;
  ImageProvider? lastProcessedImage;

  Color _getContrastColor(Color backgroundColor) {
    // Calculate relative luminance
    final luminance = backgroundColor.computeLuminance();
    // Return white for dark backgrounds, black for light backgrounds
    return luminance > 0.7 ? Colors.black : Colors.white;
  }

  Future<void> _extractDominantColor(ImageProvider imageProvider) async {
    if (lastProcessedImage == imageProvider) return;

    final paletteGenerator = await PaletteGenerator.fromImageProvider(imageProvider, maximumColorCount: 10);

    // Get dominant color, excluding black/very dark colors
    Color? selectedColor = paletteGenerator.dominantColor?.color;

    // If dominant color is too dark, try vibrant or muted colors
    if (selectedColor != null && selectedColor.computeLuminance() < 0.1) {
      selectedColor = paletteGenerator.vibrantColor?.color ?? paletteGenerator.mutedColor?.color ?? selectedColor;
    }

    if (mounted) {
      setState(() {
        dominantColor = selectedColor;
        contrastColor = selectedColor != null ? _getContrastColor(selectedColor) : null;
        lastProcessedImage = imageProvider;
      });
    }
  }

  String _formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(secs)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ListenableBuilder(
          listenable: musicService,
          builder: (context, child) {
            final playerData = musicService.playerData;
            if (playerData == null) {
              return Container();
            }

            if (playerData.art != null && playerData.art != lastProcessedImage) {
              _extractDominantColor(playerData.art!);
            }

            final EdgeInsets viewPadding = MediaQuery.of(context).padding;

            return Material(
              color: Colors.black.withOpacity(0.18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (playerData.art != null)
                    Opacity(
                      opacity: 1,
                      child: Image(image: playerData.art!, fit: BoxFit.cover),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [playerData.gradientStart, playerData.gradientEnd]),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.fromRGBO(0, 0, 0, 0.2), dominantColor?.withAlpha(70) ?? Color.fromRGBO(0, 0, 0, 0.3)]),
                    ),
                  ),
                  Positioned(
                    top: viewPadding.top,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up, color: Colors.white),
                        Expanded(
                          child: Slider(value: playerData.volume.clamp(0.0, 1.0).toDouble(), min: 0, max: 1, onChanged: musicService.setVolume),
                        ),
                        IconButton(
                          color: Colors.white,
                          onPressed: () {
                            FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.musicPlayer);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          playerData.title,
                          style: TextStyle(color: contrastColor, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playerData.artist.toString(),
                          style: TextStyle(color: contrastColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              color: contrastColor,
                              onPressed: () async {
                                await musicService.playerData?.previous();
                              },
                              icon: Icon(Icons.skip_previous),
                            ),
                            IconButton(
                              color: contrastColor,
                              onPressed: () async {
                                if (musicService.playerData!.isPlaying) {
                                  await musicService.playerData?.pause();
                                } else {
                                  await musicService.playerData?.play();
                                }
                              },
                              icon: Icon(musicService.playerData!.isPlaying ? Icons.pause : Icons.play_arrow),
                            ),
                            IconButton(
                              color: contrastColor,
                              onPressed: () async {
                                await musicService.playerData?.next();
                              },
                              icon: Icon(Icons.skip_next),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_formatDuration(musicService.playerData!.position), style: TextStyle(color: contrastColor)),
                            Slider(
                              value: musicService.playerData!.position.toDouble(),
                              max: musicService.playerData!.length.toDouble(),
                              onChanged: (value) {
                                musicService.seek(value);
                              },
                            ),
                            Text(_formatDuration(musicService.playerData!.length), style: TextStyle(color: contrastColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

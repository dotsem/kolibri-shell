import 'dart:ui';
import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/music/music_info.dart';
import 'package:hypr_flutter/panels/taskbar/widgets/music/music_controls.dart';
import 'package:hypr_flutter/services/music.dart';
import 'package:hypr_flutter/window_ids.dart';
import 'package:palette_generator/palette_generator.dart';

class MusicPanel extends StatefulWidget {
  const MusicPanel({super.key});

  @override
  State<MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<MusicPanel> {
  final MusicService musicService = MusicService();

  bool hovered = false;
  Color? dominantColor;
  Color? contrastColor;
  ImageProvider? lastProcessedImage;
  bool musicPlayerPanelVisible = false;

  Color _getContrastColor(Color backgroundColor) {
    // Calculate relative luminance
    final luminance = backgroundColor.computeLuminance();
    // Return white for dark backgrounds, black for light backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: musicService,
      builder: (context, child) {
        final playerData = musicService.playerData;

        if (playerData == null) {
          return Container();
        }

        // Extract dominant color when album art changes
        if (playerData.art != null && playerData.art != lastProcessedImage) {
          _extractDominantColor(playerData.art!);
        }

        return InputRegion(
          child: MouseRegion(
            onEnter: (event) {
              setState(() {
                hovered = true;
              });
            },
            onExit: (event) {
              setState(() {
                hovered = false;
              });
            },
            child: GestureDetector(
              onTap: () async {
                if (await FlLinuxWindowManager.instance.isVisible(windowId: WindowIds.musicPlayer)) {
                  musicPlayerPanelVisible = false;
                  await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.musicPlayer);
                } else {
                  await FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.musicPlayer);
                  musicPlayerPanelVisible = true;
                }
              },
              child: SizedBox(
                width: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Blurred background
                      if (playerData.art != null)
                        Positioned.fill(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Image(image: playerData.art!, fit: BoxFit.cover),
                          ),
                        ),
                      // Dominant color overlay mixed with blurred image
                      if (dominantColor != null)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [dominantColor!.withValues(alpha: 0.2), dominantColor!.withValues(alpha: 0.2)]),
                            ),
                          ),
                        ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          textTheme: contrastColor != null ? Theme.of(context).textTheme.apply(bodyColor: contrastColor, displayColor: contrastColor) : Theme.of(context).textTheme,
                          sliderTheme: contrastColor != null ? SliderThemeData(activeTrackColor: contrastColor, inactiveTrackColor: contrastColor!.withOpacity(0.3)) : Theme.of(context).sliderTheme,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: playerData.art != null ? Image(image: playerData.art!, width: 48, height: 48, fit: BoxFit.cover) : Container(width: 48, height: 48, color: Theme.of(context).colorScheme.surface, child: Icon(Icons.album)),
                            ),
                            hovered
                                ? MusicControls(
                                    playerData: playerData,
                                    updatePlayerData: () {
                                      // The D-Bus listener will automatically update when properties change
                                      // But we can manually trigger an update for immediate feedback
                                      musicService.getPlayerData();
                                    },
                                  )
                                : MusicInfo(playerData: playerData),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

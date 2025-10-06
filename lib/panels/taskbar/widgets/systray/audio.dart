import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/audio.dart';

class AudioIndicator extends StatefulWidget {
  const AudioIndicator({super.key});

  @override
  State<AudioIndicator> createState() => _AudioIndicatorState();
}

class _AudioIndicatorState extends State<AudioIndicator> {
  final AudioService _audioService = AudioService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audioService,
      builder: (_, __) {
        if (!_audioService.available) {
          return const SizedBox.shrink();
        }

        final int volumePercent = _audioService.volumePercent;
        final bool muted = _audioService.muted || volumePercent == 0;

        final IconData icon = _iconForVolume(muted, volumePercent);
        final String label = muted ? 'Muted' : '$volumePercent%';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForVolume(bool muted, int volumePercent) {
    if (muted || volumePercent == 0) {
      return Icons.volume_off_rounded;
    }

    if (volumePercent < 30) {
      return Icons.volume_mute_rounded;
    }

    if (volumePercent < 70) {
      return Icons.volume_down_rounded;
    }

    return Icons.volume_up_rounded;
  }
}

import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/music.dart';

typedef MusicInfoCallback = void Function(double value);

class MusicControls extends StatefulWidget {
  const MusicControls({super.key, required this.playerData, required this.updatePlayerData, required this.positionChanged});

  final MusicPlayer playerData;
  final VoidCallback updatePlayerData;
  final MusicInfoCallback positionChanged;

  @override
  State<MusicControls> createState() => _MusicControlsState();
}

class _MusicControlsState extends State<MusicControls> {
  double? _pendingPosition;

  double get _maxPosition => widget.playerData.length.toDouble().clamp(1, double.infinity);

  double get _currentPosition {
    final double livePosition = widget.playerData.position.toDouble().clamp(0, _maxPosition);
    return _pendingPosition?.clamp(0, _maxPosition) ?? livePosition;
  }

  String _formatDuration(double seconds) {
    final int totalSeconds = seconds.isNaN ? 0 : seconds.clamp(0, double.maxFinite).round();
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_currentPosition), style: Theme.of(context).textTheme.labelSmall),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                    onPressed: () async {
                      await widget.playerData.previous();
                      widget.updatePlayerData();
                    },
                    icon: const Icon(Icons.skip_previous),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: IconButton(
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                      onPressed: () async {
                        await (widget.playerData.isPlaying ? widget.playerData.pause() : widget.playerData.play());
                        widget.updatePlayerData();
                      },
                      icon: Icon(widget.playerData.isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                  IconButton(
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                    onPressed: () async {
                      await widget.playerData.next();
                      widget.updatePlayerData();
                    },
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              Text(_formatDuration(_maxPosition), style: Theme.of(context).textTheme.labelSmall),
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
              value: _currentPosition,
              max: _maxPosition,
              onChanged: (value) {
                setState(() => _pendingPosition = value);
              },
              onChangeEnd: (value) {
                setState(() => _pendingPosition = null);
                widget.positionChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

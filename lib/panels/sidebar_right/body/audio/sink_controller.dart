import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/audio_slider.dart';
import 'package:pulseaudio/pulseaudio.dart';

class SinkController extends StatefulWidget {
  final List<PulseAudioSink> sinks;
  final PulseAudioClient client;
  const SinkController({super.key, required this.sinks, required this.client});

  @override
  State<SinkController> createState() => _SinkControllerState();
}

class _SinkControllerState extends State<SinkController> {
  @override
  Widget build(BuildContext context) {
    return RadioGroup(
      groupValue: null,
      onChanged: (value) {},
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: widget.sinks.length,
        itemBuilder: (context, index) {
          PulseAudioSink sink = widget.sinks[index];
          return AudioSlider(
            value: sink.volume,
            onVolumeChange: (volume) {
              setState(() {
                widget.client.setSinkVolume(sink.name, volume);
              });
            },
            muted: sink.mute,
            onMute: (muted) {
              setState(() {
                widget.client.setSinkMute(sink.name, muted);
              });
            },
            identifier: sink.name,
            title: sink.description,
          );
        },
      ),
    );
  }
}

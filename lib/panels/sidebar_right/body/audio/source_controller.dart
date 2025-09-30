import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/audio_slider.dart';
import 'package:pulseaudio/pulseaudio.dart';

class SourceController extends StatefulWidget {
  final List<PulseAudioSource> sources;
  final PulseAudioClient client;
  const SourceController({super.key, required this.sources, required this.client});

  @override
  State<SourceController> createState() => _SourceControllerState();
}

class _SourceControllerState extends State<SourceController> {
  String defaultSource = "";

  @override
  void initState() {
    super.initState();
    widget.client.getServerInfo().then((info) {
      setState(() {
        defaultSource = info.defaultSourceName;
      });
    });

    widget.client.onServerInfoChanged.listen((event) {
      setState(() {
        defaultSource = event.defaultSourceName;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return RadioGroup(
      groupValue: defaultSource,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            defaultSource = value;
            widget.client.setDefaultSource(value);
          }
        });
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: widget.sources.length,
        itemBuilder: (context, index) {
          PulseAudioSource source = widget.sources[index];
          return AudioSlider(
            value: source.volume,
            onVolumeChange: (volume) {
              setState(() {
                widget.client.setSourceVolume(source.name, volume);
              });
            },
            muted: source.mute,
            onMute: (muted) {
              setState(() {
                widget.client.setSourceMute(source.name, muted);
              });
            },
            identifier: source.name,
            title: source.description,
            icon: Icons.mic,
            iconMuted: Icons.mic_off,
          );
        },
      ),
    );
  }
}

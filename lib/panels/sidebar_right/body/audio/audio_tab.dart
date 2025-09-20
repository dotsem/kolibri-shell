import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/sink_controller.dart';
import 'package:pulseaudio/pulseaudio.dart';

class AudioTab extends StatefulWidget {
  const AudioTab({super.key});

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab> {
  List<PulseAudioSink> sinks = [];
  final client = PulseAudioClient();
  @override
  void initState() {
    super.initState();

    client.initialize().then((_) {
      client.getSinkList().then((sinkList) {
        setState(() {
          sinks = sinkList;
        });
      });
    });

    client.onSinkChanged.listen((event) {
      client.getSinkList().then((sinkList) {
        setState(() {
          sinks = sinkList;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [SinkController(sinks: sinks, client: client)],
        ),
      ),
    );
  }
}

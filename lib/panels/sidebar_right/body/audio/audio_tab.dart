import 'package:flutter/material.dart';
import 'package:pulseaudio/pulseaudio.dart';

class AudioTab extends StatefulWidget {
  const AudioTab({super.key});

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab> {
  @override
  void initState() {
    super.initState();

    final client = PulseAudioClient();
    client.initialize().then((_) {
      client.getSinkList().then((sinkList) {
        print('\nAvailable Sinks:');
        for (var sink in sinkList) {
          print('Sink Name: ${sink.name}, Description: ${sink.description}');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text("tab audio");
  }
}

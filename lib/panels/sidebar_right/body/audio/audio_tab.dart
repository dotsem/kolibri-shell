import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/audio_slider.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/audio/sink_controller.dart';
import 'package:pulseaudio/pulseaudio.dart';

class AudioTab extends StatefulWidget {
  const AudioTab({super.key});

  @override
  State<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends State<AudioTab> {
  bool initialized = false;
  List<PulseAudioSink> sinks = [];
  final client = PulseAudioClient();
  @override
  void initState() {
    super.initState();

    client.initialize().then((_) {
      client.getSinkList().then((sinkList) {
        setState(() {
          sinks = sinkList;
          initialized = true;

          client.getSourceList().then((sourceList) {
            for (PulseAudioSource source in sourceList) {
              print("bub source: ${source.name} ${source.description}");
            }
          });
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
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return initialized
        ? Expanded(
            child: Column(
              children: [
                Text("system"),
                DefaultTabController(
                  length: 3,
                  child: Expanded(
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text("Apps"),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.speaker_group_rounded),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text("Outputs"),
                                  ),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings_input_component),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text("Inputs"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              Center(child: Text("tab 1")),
                              SinkController(sinks: sinks, client: client),
                              Center(child: Text("tab 3")),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : Container();
  }
}

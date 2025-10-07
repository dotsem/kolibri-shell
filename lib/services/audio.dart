import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pulseaudio/pulseaudio.dart';

class AudioService extends ChangeNotifier {
  AudioService._internal() {
    _initialize();
  }

  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final PulseAudioClient _client = PulseAudioClient();

  bool _initializing = false;
  bool _initialized = false;
  PulseAudioSink? _defaultSink;
  String? _defaultSinkName;

  StreamSubscription? _sinkSubscription;
  StreamSubscription? _sinkRemovedSubscription;
  StreamSubscription? _serverInfoSubscription;
  Timer? _recoveryTimer;
  int _recoveryAttempts = 0;

  bool get available => _initialized && _defaultSink != null;
  bool get muted => _defaultSink?.mute ?? false;
  double get volume => (_defaultSink?.volume ?? 0).clamp(0.0, 1.0);
  String? get sinkDescription => _defaultSink?.description;

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;

    try {
      await _client.initialize();
      await _loadServerInfo();

      _serverInfoSubscription = _client.onServerInfoChanged.listen((info) {
        _defaultSinkName = info.defaultSinkName;
        _refreshDefaultSink();
      });

      _sinkSubscription = _client.onSinkChanged.listen((_) {
        _refreshDefaultSink();
      });

      _sinkRemovedSubscription = _client.onSinkRemoved.listen((_) {
        _handleSinkLoss();
      });

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('AudioService initialization failed: $e');
      debugPrint(stackTrace.toString());
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadServerInfo() async {
    try {
      final info = await _client.getServerInfo();
      _defaultSinkName = info.defaultSinkName;
      await _refreshDefaultSink();
    } catch (e) {
      debugPrint('AudioService failed to load server info: $e');
      _defaultSink = null;
    }
  }

  Future<void> _refreshDefaultSink() async {
    try {
      final sinks = await _client.getSinkList();
      _defaultSink = _findSinkByName(sinks, _defaultSinkName);
      if (_defaultSink == null && sinks.isNotEmpty) {
        _defaultSink = sinks.first;
        _defaultSinkName = _defaultSink?.name;
      }

      if (_defaultSink == null) {
        _handleSinkLoss();
        return;
      }

      _resetRecoveryState();
    } catch (e) {
      debugPrint('AudioService failed to refresh sinks: $e');
      _handleSinkLoss();
      return;
    }

    notifyListeners();
  }

  PulseAudioSink? _findSinkByName(List<PulseAudioSink> sinks, String? name) {
    if (name == null) return null;
    for (final sink in sinks) {
      if (sink.name == name) {
        return sink;
      }
    }
    return null;
  }

  int get volumePercent => (volume * 100).round().clamp(0, 100);

  Future<void> setMuted(bool mute) async {
    final sink = _defaultSink;
    if (sink == null) return;

    try {
      await _client.setSinkMute(sink.name, mute);
      await _refreshDefaultSink();
    } catch (e) {
      debugPrint('AudioService failed to set mute: $e');
    }
  }

  Future<void> setVolume(double newVolume) async {
    final sink = _defaultSink;
    if (sink == null) return;

    final clamped = newVolume.clamp(0.0, 1.0);

    try {
      await _client.setSinkVolume(sink.name, clamped);
      await _refreshDefaultSink();
    } catch (e) {
      debugPrint('AudioService failed to set volume: $e');
    }
  }

  Future<void> disposeService() async {
    await _sinkSubscription?.cancel();
    await _sinkRemovedSubscription?.cancel();
    await _serverInfoSubscription?.cancel();
    _recoveryTimer?.cancel();
    try {
      await _client.dispose();
    } catch (_) {}
  }

  void _handleSinkLoss() {
    if (_defaultSink != null) {
      _defaultSink = null;
      notifyListeners();
    }
    _scheduleRecovery();
  }

  void _scheduleRecovery() {
    if (_recoveryTimer != null) {
      return;
    }
    const maxAttempts = 5;
    if (_recoveryAttempts >= maxAttempts) {
      return;
    }
    _recoveryTimer = Timer(const Duration(seconds: 2), () async {
      _recoveryTimer?.cancel();
      _recoveryTimer = null;
      _recoveryAttempts++;
      await _loadServerInfo();
      if (_defaultSink == null) {
        _scheduleRecovery();
      } else {
        _resetRecoveryState();
      }
    });
  }

  void _resetRecoveryState() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryAttempts = 0;
  }
}

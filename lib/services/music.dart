import 'dart:async';
import 'dart:ui' show Color;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSLColor;
import 'package:dbus/dbus.dart';
import 'package:palette_generator/palette_generator.dart';

class MusicService extends ChangeNotifier {
  DBusClient? _dbusClient;
  DBusRemoteObject? _playerObject;
  String currentPlayer = "spotify";
  MusicPlayer? playerData;
  StreamSubscription? _propertiesSubscription;
  StreamSubscription? _seekedSubscription;
  Timer? _positionTimer;
  int _currentPosition = 0;

  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal() {
    _initialize();
  }

  Color _deriveGradientColor(Color source, {double darkness = 0.08, double saturationScale = 0.94, double opacity = 0.42}) {
    final HSLColor hsl = HSLColor.fromColor(source);
    final double adjustedLightness = (hsl.lightness * (1 - darkness)).clamp(0.0, 1.0);
    final double adjustedSaturation = (hsl.saturation * saturationScale).clamp(0.0, 1.0);
    final HSLColor adjusted = hsl.withLightness(adjustedLightness).withSaturation(adjustedSaturation);
    return adjusted.toColor().withOpacity(opacity.clamp(0.0, 1.0));
  }

  Future<void> setVolume(double value) async {
    final MusicPlayer? player = playerData;
    if (player == null) {
      return;
    }

    await player.setVolume(value.clamp(0.0, 1.0));
    notifyListeners();
  }

  Future<void> _initialize() async {
    try {
      _dbusClient = DBusClient.session();

      // List all MPRIS players
      final names = await _dbusClient!.listNames();
      final mprisPlayers = names.where((name) => name.startsWith('org.mpris.MediaPlayer2.')).toList();

      if (mprisPlayers.isNotEmpty) {
        // Use the first available player or find spotify
        final spotifyPlayer = mprisPlayers.firstWhere((name) => name.contains('spotify'), orElse: () => mprisPlayers.first);
        currentPlayer = spotifyPlayer.split('.').last;

        print('Found MPRIS player: $currentPlayer');
        await _connectToPlayer(spotifyPlayer);
      }
    } catch (e) {
      print('Failed to initialize music service: $e');
    }
  }

  Future<void> _connectToPlayer(String destination) async {
    final path = DBusObjectPath('/org/mpris/MediaPlayer2');
    _playerObject = DBusRemoteObject(_dbusClient!, name: destination, path: path);

    // Listen to property changes
    _propertiesSubscription = _playerObject!.propertiesChanged.listen((signal) {
      if (signal.propertiesInterface == 'org.mpris.MediaPlayer2.Player') {
        print('MPRIS properties changed, updating...');
        getPlayerData();
      }
    });

    // Listen to Seeked signal for instant position updates
    final seekedSignals = DBusRemoteObjectSignalStream(object: _playerObject!, interface: 'org.mpris.MediaPlayer2.Player', name: 'Seeked');

    _seekedSubscription = seekedSignals.listen((signal) {
      if (signal.values.isNotEmpty && signal.values[0] is DBusInt64) {
        final newPositionMicros = (signal.values[0] as DBusInt64).value;
        _currentPosition = (newPositionMicros / 1000000).round();
        if (playerData != null) {
          playerData!.position = _currentPosition;
          notifyListeners();
        }
        print('🎯 Seeked signal received! New position: $_currentPosition seconds');
      }
    });

    await getPlayerData();
    print('Connected to player: $destination');
  }

  // Get all player data from D-Bus
  Future<void> getPlayerData() async {
    if (_playerObject == null) {
      print('ERROR: _playerObject is null!');
      return;
    }

    try {
      print('Fetching player data...');
      // Get all properties at once
      final metadata = await _getProperty('Metadata');
      final volume = await _getProperty('Volume');
      final playbackStatus = await _getProperty('PlaybackStatus');
      final position = await _getProperty('Position');

      print('Got properties, parsing metadata...');
      // Parse metadata
      final metadataMap = (metadata as DBusDict).children;
      print('Metadata map keys: ${metadataMap.keys.map((k) => (k as DBusString).value).toList()}');

      final title = _getMetadataString(metadataMap, 'xesam:title');
      final artists = _getMetadataStringArray(metadataMap, 'xesam:artist');
      final album = _getMetadataString(metadataMap, 'xesam:album');
      final trackId = _getMetadataString(metadataMap, 'mpris:trackid');
      final artUrl = _getMetadataString(metadataMap, 'mpris:artUrl');
      final lengthMicros = _getMetadataInt(metadataMap, 'mpris:length');

      print('Parsed: title=$title, artist=${artists.isNotEmpty ? artists.first : "Unknown"}');

      final isPlaying = (playbackStatus as DBusString).value == 'Playing';
      final volumeValue = (volume as DBusDouble).value;
      final positionMicros = (position as DBusInt64).value;

      _currentPosition = (positionMicros / 1000000).round();
      final length = (lengthMicros / 1000000).round();

      CachedNetworkImageProvider? artProvider;
      Color gradientStart = const Color.fromRGBO(0, 0, 0, 0.18);
      Color gradientEnd = const Color.fromRGBO(0, 0, 0, 0.14);

      if (artUrl.isNotEmpty) {
        artProvider = CachedNetworkImageProvider(artUrl, maxWidth: 256, maxHeight: 256);
        try {
          final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(artProvider, maximumColorCount: 10);

          final List<PaletteColor> paletteColors = palette.paletteColors.toList()..sort((a, b) => b.population.compareTo(a.population));

          if (paletteColors.isNotEmpty) {
            gradientStart = _deriveGradientColor(paletteColors.first.color, darkness: 0.06, saturationScale: 0.97, opacity: 0.38);
          }

          if (paletteColors.length > 1) {
            gradientEnd = _deriveGradientColor(paletteColors[1].color, darkness: 0.1, saturationScale: 0.95, opacity: 0.35);
          } else {
            gradientEnd = _deriveGradientColor(gradientStart.withOpacity(1.0), darkness: 0.12, saturationScale: 0.92, opacity: 0.32);
          }
        } catch (e) {
          debugPrint('Failed to generate palette for gradients: $e');
        }
      }

      playerData = MusicPlayer(
        _playerObject!,
        title,
        artists.isNotEmpty ? artists : ['Unknown'],
        album,
        trackId,
        artUrl,
        length,
        volumeValue,
        isPlaying,
        _currentPosition,
        artProvider: artProvider,
        gradientStart: gradientStart,
        gradientEnd: gradientEnd,
      );

      _startPositionTimer(isPlaying);
      notifyListeners();
    } catch (e) {
      print('Failed to get player data: $e');
    }
  }

  // Helper to get a property from the player
  Future<DBusValue> _getProperty(String property) async {
    return await _playerObject!.getProperty('org.mpris.MediaPlayer2.Player', property);
  }

  // Helper to extract string from metadata (handles DBusVariant)
  String _getMetadataString(Map<DBusValue, DBusValue> metadata, String key) {
    final value = metadata[DBusString(key)];
    if (value == null) return '';

    // Unwrap variant if needed
    final unwrapped = value is DBusVariant ? value.value : value;
    if (unwrapped is DBusString) return unwrapped.value;
    return '';
  }

  // Helper to extract string array from metadata (handles DBusVariant)
  List<String> _getMetadataStringArray(Map<DBusValue, DBusValue> metadata, String key) {
    final value = metadata[DBusString(key)];
    if (value == null) return [];

    return _extractStringsFromValue(value);
  }

  List<String> _extractStringsFromValue(DBusValue value) {
    final DBusValue unwrapped = value is DBusVariant ? value.value : value;
    if (unwrapped is DBusString) {
      return <String>[unwrapped.value];
    }
    if (unwrapped is DBusArray) {
      final List<String> results = <String>[];
      for (final DBusValue entry in unwrapped.children) {
        results.addAll(_extractStringsFromValue(entry));
      }
      return results;
    }
    return const <String>[];
  }

  // Helper to extract int from metadata (handles DBusVariant)
  int _getMetadataInt(Map<DBusValue, DBusValue> metadata, String key) {
    final value = metadata[DBusString(key)];
    if (value == null) return 0;

    // Unwrap variant if needed
    final unwrapped = value is DBusVariant ? value.value : value;
    if (unwrapped is DBusInt64) return unwrapped.value;
    if (unwrapped is DBusUint64) return unwrapped.value;
    return 0;
  }

  // Start timer to update position
  void _startPositionTimer(bool isPlaying) {
    _positionTimer?.cancel();

    if (playerData != null) {
      // Check D-Bus position every 500ms for faster seek detection
      _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        if (playerData != null && _playerObject != null) {
          try {
            final position = await _getProperty('Position');
            _currentPosition = ((position as DBusInt64).value / 1000000).round();
            playerData!.position = _currentPosition;
            notifyListeners();
          } catch (e) {
            // If we can't get position, increment locally if playing
            if (isPlaying && _currentPosition < playerData!.length) {
              _currentPosition++;
              playerData!.position = _currentPosition;
              notifyListeners();
            }
          }
        }
      });
    }
  }

  Future<void> seek(double seconds) async {
    if (_playerObject == null) {
      print('Cannot seek: player object is null');
      return;
    }

    if (playerData == null) {
      print('Cannot seek: player data is unavailable');
      return;
    }

    final targetSeconds = seconds.clamp(0, playerData!.length.toDouble()).round();

    try {
      await playerData!.setPosition(targetSeconds);
      _currentPosition = targetSeconds;
      playerData!.position = targetSeconds;
      notifyListeners();
    } catch (e) {
      print('Failed to seek: $e');
    }
  }

  @override
  void dispose() {
    _propertiesSubscription?.cancel();
    _seekedSubscription?.cancel();
    _positionTimer?.cancel();
    _dbusClient?.close();
    super.dispose();
  }
}

class MusicPlayer {
  final DBusRemoteObject _playerObject;
  final String title;
  final List<String> artist;
  final String album;
  final String trackId;
  final String artUrl;
  bool isPlaying;
  double volume;
  int length;
  int position;
  final CachedNetworkImageProvider? art;
  final Color gradientStart;
  final Color gradientEnd;

  MusicPlayer(
    this._playerObject,
    this.title,
    this.artist,
    this.album,
    this.trackId,
    this.artUrl,
    this.length,
    this.volume,
    this.isPlaying,
    this.position, {
    CachedNetworkImageProvider? artProvider,
    required this.gradientStart,
    required this.gradientEnd,
  }) : art = artProvider ?? (artUrl.isNotEmpty ? CachedNetworkImageProvider(artUrl, maxWidth: 256, maxHeight: 256) : null) {
    print("✅ MusicPlayer created:");
    print("   Title: $title");
    print("   Artist: $artist");
    print("   Album: $album");
    print("   Playing: $isPlaying");
    print("   Position: $position / $length seconds");
  }

  // Call D-Bus method helper
  Future<void> _callMethod(String method) async {
    try {
      await _playerObject.callMethod('org.mpris.MediaPlayer2.Player', method, [], replySignature: DBusSignature(''));
    } catch (e) {
      print('Failed to call $method: $e');
    }
  }

  Future<void> play() async {
    await _callMethod('Play');
  }

  Future<void> pause() async {
    await _callMethod('Pause');
  }

  Future<void> next() async {
    await _callMethod('Next');
  }

  Future<void> previous() async {
    await _callMethod('Previous');
  }

  Future<void> setVolume(double newVolume) async {
    try {
      await _playerObject.setProperty('org.mpris.MediaPlayer2.Player', 'Volume', DBusDouble(newVolume));
      volume = newVolume;
    } catch (e) {
      print('Failed to set volume: $e');
    }
  }

  Future<void> setPosition(int positionSeconds) async {
    try {
      if (trackId.isEmpty) {
        print('Cannot set position: trackId is empty');
        return;
      }

      final clampedPosition = positionSeconds.clamp(0, length).toInt();

      await _playerObject.callMethod('org.mpris.MediaPlayer2.Player', 'SetPosition', [DBusObjectPath(trackId), DBusInt64(clampedPosition * 1000000)], replySignature: DBusSignature(''));

      position = clampedPosition;
    } catch (e) {
      print('Failed to set position: $e');
    }
  }
}

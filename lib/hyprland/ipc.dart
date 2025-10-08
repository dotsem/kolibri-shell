import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';

/// Hyprland event types from socket2 (as per IPC documentation)
enum HyprlandEventType {
  workspace,
  workspacev2,
  focusedmon,
  focusedmonv2,
  activewindow,
  activewindowv2,
  fullscreen,
  monitorremoved,
  monitoradded,
  openwindow,
  closewindow,
  movewindow,
  movewindowv2,
  windowtitle,
  windowtitlev2,
  openlayer,
  closelayer,
  submap,
  changefloatingmode,
  urgent,
  minimize,
  screencast,
  configreloaded,
  layeropen,
  layerclose,
  unknown, // For unhandled events
}

/// Parsed Hyprland event
class HyprlandEvent {
  final HyprlandEventType type;
  final List<String> data;
  final DateTime timestamp;

  HyprlandEvent(this.type, this.data, this.timestamp);

  @override
  String toString() => 'HyprlandEvent{type: $type, data: $data}';
}

/// Main IPC Manager Singleton
class HyprlandIpcManager {
  // Private constructor
  HyprlandIpcManager._() {
    _init();
  }

  // Singleton instance
  static final HyprlandIpcManager _instance = HyprlandIpcManager._();
  static HyprlandIpcManager get instance => _instance;

  // Socket connection
  Socket? _socket;
  StreamSubscription<Uint8List>? _socketSubscription;
  String _pendingChunk = '';

  // Individual streams for each event type
  final Map<HyprlandEventType, BehaviorSubject<HyprlandEvent>> _eventStreams = {};

  // Connection status
  final _connectionController = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get connectionStream => _connectionController.stream;

  // Initialize the singleton
  void _init() {
    // Create a stream controller for each event type
    for (var eventType in HyprlandEventType.values) {
      _eventStreams[eventType] = BehaviorSubject<HyprlandEvent>();
    }

    _connectToHyprland();
  }

  /// Get stream for specific event type
  Stream<HyprlandEvent> getEventStream(HyprlandEventType eventType) {
    return _eventStreams[eventType]!.stream;
  }

  /// Connect to Hyprland socket2
  Future<void> _connectToHyprland() async {
    try {
      final instanceSignature = Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'];
      final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];

      if (instanceSignature == null || runtimeDir == null) {
        throw Exception('Hyprland environment variables not found');
      }

      final socketPath = '$runtimeDir/hypr/$instanceSignature/.socket2.sock';
      print('🔄 Connecting to Hyprland socket: $socketPath');

      final host = InternetAddress(socketPath, type: InternetAddressType.unix);
      // Connect to Unix domain socket
      _socket = await Socket.connect(host, 0, timeout: const Duration(seconds: 3));

      // Subscribe to all events
      _socket!.write('subscribe []\n');
      await _socket!.flush();

      _connectionController.add(true);
      print('✅ Connected to Hyprland IPC successfully!');

      // Listen for events
      _socketSubscription = _socket!.listen(_handleSubscriptionData, onError: _handleError, onDone: _handleDisconnect);
    } catch (e) {
      print('❌ Connection failed: $e');
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleSubscriptionData(Uint8List rawData) {
    try {
      final String chunk = utf8.decode(rawData);
      final String combined = _pendingChunk + chunk;
      final List<String> lines = combined.split('\n');
      _pendingChunk = lines.removeLast();

      for (final String line in lines) {
        if (line.isNotEmpty) {
          _parseEvent(line);
        }
      }
    } on FormatException catch (error) {
      print('Hyprland IPC decode error: $error');
      _pendingChunk = '';
    }
  }

  /// Parse incoming event data
  void _parseEvent(String data) {
    try {
      // print("hyprland event: $data");

      // Format: "eventType>>data,data,data"
      final parts = data.split('>>');
      if (parts.length != 2) return;

      final eventName = parts[0].trim();
      final eventData = parts[1].split(',').map((e) => e.trim()).toList();

      // Map to enum
      final eventType = _stringToEventType(eventName);
      if (eventType == HyprlandEventType.unknown) {
        // print('⚠️  Unknown event type: $eventName');
        return;
      }

      final event = HyprlandEvent(eventType, eventData, DateTime.now());

      // Send to appropriate stream
      _eventStreams[eventType]!.add(event);
    } catch (e) {
      print('Error parsing event: $e | Data: $data');
    }
  }

  /// Convert string to event type enum
  HyprlandEventType _stringToEventType(String name) {
    try {
      return HyprlandEventType.values.firstWhere((e) => e.name == name, orElse: () => HyprlandEventType.unknown);
    } catch (_) {
      return HyprlandEventType.unknown;
    }
  }

  /// Handle socket errors
  void _handleError(Object error) {
    print('Socket error: $error');
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// Handle socket disconnect
  void _handleDisconnect() {
    print('Socket disconnected');
    _connectionController.add(false);
    _pendingChunk = '';
    _scheduleReconnect();
  }

  /// Schedule reconnection
  void _scheduleReconnect() {
    Timer(const Duration(seconds: 2), () {
      _socketSubscription?.cancel();
      _socket?.destroy();
      _connectToHyprland();
    });
  }

  /// Dispose resources
  Future<void> dispose() async {
    for (var controller in _eventStreams.values) {
      await controller.close();
    }
    await _connectionController.close();
    await _socketSubscription?.cancel();
    _socket?.destroy();
  }
}

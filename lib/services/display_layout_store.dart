import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:hypr_flutter/models/display_layout.dart';

class DisplayLayoutStore {
  DisplayLayoutStore._internal();

  static final DisplayLayoutStore _instance = DisplayLayoutStore._internal();
  factory DisplayLayoutStore() => _instance;

  final StreamController<DisplayLayoutsBundle> _controller = StreamController<DisplayLayoutsBundle>.broadcast();
  StreamSubscription<FileSystemEvent>? _watchSubscription;

  DisplayLayoutsBundle _cache = DisplayLayoutsBundle.empty();
  bool _initialized = false;
  String? _overridePath;

  String get _filePath => _overridePath ?? p.join(_resolveConfigHome(), 'displays.json');

  Stream<DisplayLayoutsBundle> get stream => _controller.stream;

  DisplayLayoutsBundle get currentBundle => _cache;

  set overridePathForTesting(String? path) {
    if (_initialized) {
      throw StateError('overridePathForTesting must be set before initialize()');
    }
    _overridePath = path;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _ensureStorage();
    await _loadFromDisk();
    _watchFile();
    _initialized = true;
  }

  Future<DisplayLayoutsBundle> loadBundle() async {
    if (!_initialized) {
      await initialize();
    }
    return _cache;
  }

  Future<void> saveBundle(DisplayLayoutsBundle bundle) async {
    await initialize();

    final file = File(_filePath);
    final encoded = bundle.toPrettyJson();
    await file.writeAsString(encoded);
    _cache = bundle;
    _controller.add(_cache);
  }

  Future<void> dispose() async {
    await _watchSubscription?.cancel();
    await _controller.close();
    _initialized = false;
  }

  Future<void> _ensureStorage() async {
    final folder = Directory(p.dirname(_filePath));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final file = File(_filePath);
    if (!await file.exists()) {
      final bundle = DisplayLayoutsBundle.empty();
      await file.writeAsString(bundle.toPrettyJson());
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = File(_filePath);
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _cache = DisplayLayoutsBundle.empty();
      } else {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _cache = DisplayLayoutsBundle.fromJson(decoded);
        } else {
          throw const FormatException('Invalid root JSON type');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('DisplayLayoutStore: failed to read layouts: $error');
      debugPrint('$stackTrace');
      _cache = DisplayLayoutsBundle.empty();
    }

    _controller.add(_cache);
  }

  void _watchFile() {
    final file = File(_filePath);
    _watchSubscription = file.watch(events: FileSystemEvent.modify).listen((_) {
      _handleExternalChange();
    }, onError: (Object error) {
      debugPrint('DisplayLayoutStore: watch error: $error');
    });
  }

  Future<void> _handleExternalChange() async {
    try {
      await _loadFromDisk();
    } catch (error, stackTrace) {
      debugPrint('DisplayLayoutStore: failed to reload after change: $error');
      debugPrint('$stackTrace');
    }
  }

  String _resolveConfigHome() {
    final env = Platform.environment;
    final custom = env['XDG_CONFIG_HOME'];
    if (custom != null && custom.isNotEmpty) {
      return p.join(custom, 'hypr_flutter');
    }

    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      return p.join(home, '.config', 'hypr_flutter');
    }

    return p.join(Directory.current.path, '.config', 'hypr_flutter');
  }
}

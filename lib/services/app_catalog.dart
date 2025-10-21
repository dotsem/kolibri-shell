import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Represents a desktop entry exposed by an installed application.
class DesktopApp {
  DesktopApp({
    required this.id,
    required this.name,
    required this.exec,
    required this.desktopFilePath,
    this.genericName,
    this.comment,
    this.iconKey,
    this.startupWmClass,
    this.categories = const <String>[],
    this.keywords = const <String>[],
    this.noDisplay = false,
    this.terminal = false,
    Map<String, String>? rawEntries,
  }) : rawEntries = rawEntries ?? const <String, String>{};

  final String id;
  final String name;
  final String exec;
  final String desktopFilePath;
  final String? genericName;
  final String? comment;
  final String? iconKey;
  final String? startupWmClass;
  final List<String> categories;
  final List<String> keywords;
  final bool noDisplay;
  final bool terminal;
  final Map<String, String> rawEntries;

  /// Returns a sanitized command (with field codes removed) suitable for display.
  String get sanitizedExec {
    final parts = exec.split(RegExp(r'\s+'));
    final buffer = <String>[];
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.startsWith('%')) continue;
      buffer.add(part);
    }
    return buffer.join(' ');
  }
}

String? _readIniValue(String path, String section, String key) {
  final file = File(path);
  if (!file.existsSync()) return null;

  try {
    final lines = file.readAsLinesSync();
    String? currentSection;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
        continue;
      }

      if (line.startsWith('[') && line.endsWith(']')) {
        currentSection = line.substring(1, line.length - 1);
        continue;
      }

      if (!_equalsIgnoreCase(currentSection, section)) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) continue;

      final lineKey = line.substring(0, separatorIndex).trim();
      if (!_equalsIgnoreCase(lineKey, key)) continue;

      return line.substring(separatorIndex + 1).trim();
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _readGtkRcTheme(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;

  try {
    final lines = file.readAsLinesSync();
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('gtk-icon-theme-name')) continue;

      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) continue;
      return line.substring(separatorIndex + 1).trim();
    }
  } catch (_) {
    return null;
  }

  return null;
}

bool _equalsIgnoreCase(String? a, String? b) {
  if (a == null || b == null) return false;
  return a.toLowerCase() == b.toLowerCase();
}

class _ParsedIconTheme {
  const _ParsedIconTheme({required this.directories, required this.inherits});

  final List<String> directories;
  final List<String> inherits;
}

/// Service responsible for indexing desktop applications and resolving their icons.
class AppCatalogService extends ChangeNotifier {
  AppCatalogService._internal();

  static final AppCatalogService _instance = AppCatalogService._internal();

  factory AppCatalogService() => _instance;

  bool _initialized = false;
  bool _isLoading = false;
  Future<void>? _currentRefresh;

  final Map<String, DesktopApp> _appsById = <String, DesktopApp>{};
  final Map<String, List<DesktopApp>> _appsByStartupClass = <String, List<DesktopApp>>{};
  final Map<String, String?> _iconCache = <String, String?>{};

  Map<String, String>? _iconIndex;
  Future<void>? _iconIndexFuture;
  List<String>? _iconThemePreferences;
  List<String>? _iconThemeOrderCache;
  List<String>? _iconSearchDirectoryPathsCache;
  final Map<String, _ParsedIconTheme?> _parsedIconThemeCache = <String, _ParsedIconTheme?>{};

  List<String>? _applicationDirs;
  List<String>? _iconDirs;

  List<DesktopApp> get applications {
    final apps = _appsById.values.toList();
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;

  DesktopApp? getById(String id) => _appsById[id];

  DesktopApp? findByStartupWmClass(String className) {
    final normalized = className.toLowerCase();
    final matches = _appsByStartupClass[normalized];
    if (matches == null || matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  Future<void> refresh() {
    if (_currentRefresh != null) {
      return _currentRefresh!;
    }

    _isLoading = true;
    final future = _scanApplications()
        .then((apps) {
          _appsById
            ..clear()
            ..addEntries(apps.map((app) => MapEntry(app.id, app)));

          _appsByStartupClass.clear();
          for (final app in apps) {
            final key = app.startupWmClass?.toLowerCase();
            if (key == null || key.isEmpty) continue;
            _appsByStartupClass.putIfAbsent(key, () => <DesktopApp>[]).add(app);
          }

          notifyListeners();
        })
        .whenComplete(() {
          _isLoading = false;
          _currentRefresh = null;
        });

    _currentRefresh = future;
    return future;
  }

  Future<String?> iconPathFor(DesktopApp app) => resolveIcon(app.iconKey);

  Future<String?> iconPathForStartupClass(String className) async {
    final trimmed = className.trim();
    if (trimmed.isEmpty) return null;

    final DesktopApp? startupMatch = findByStartupWmClass(trimmed);
    if (startupMatch != null) {
      final direct = await iconPathFor(startupMatch);
      if (direct != null) {
        return direct;
      }

      final fallback = await resolveIcon(startupMatch.iconKey);
      if (fallback != null) {
        return fallback;
      }
    }

    for (final candidate in <String>[trimmed, trimmed.toLowerCase(), trimmed.toUpperCase()]) {
      final withDesktop = candidate.endsWith('.desktop') ? candidate : '$candidate.desktop';
      final DesktopApp? appById = getById(withDesktop);
      if (appById != null) {
        final direct = await iconPathFor(appById);
        if (direct != null) {
          return direct;
        }

        final fallback = await resolveIcon(appById.iconKey);
        if (fallback != null) {
          return fallback;
        }
      }
    }

    return resolveIcon(trimmed);
  }

  Future<String?> resolveIcon(String? icon) async {
    if (icon == null || icon.isEmpty) return null;
    final key = icon.trim();
    if (_iconCache.containsKey(key)) {
      return _iconCache[key];
    }

    final resolved = await _lookupIcon(key);
    _iconCache[key] = resolved;
    return resolved;
  }

  Future<List<DesktopApp>> _scanApplications() async {
    final Set<String> visited = <String>{};
    final Map<String, DesktopApp> results = <String, DesktopApp>{};

    for (final dirPath in _applicationDirectories) {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) continue;

      try {
        await for (final entity in directory.list(recursive: true, followLinks: true)) {
          if (entity is! File || !entity.path.endsWith('.desktop')) continue;
          if (!visited.add(entity.path)) continue;

          final entryMap = await _readDesktopFile(entity);
          if (entryMap.isEmpty) continue;
          if (!_isApplicationEntry(entryMap)) continue;
          if (_parseBool(entryMap['NoDisplay'])) continue;

          final id = p.basename(entity.path);
          final name = _selectPreferredValue(entryMap, 'Name') ?? id;
          final genericName = _selectPreferredValue(entryMap, 'GenericName');
          final comment = _selectPreferredValue(entryMap, 'Comment');
          final exec = entryMap['Exec'] ?? '';
          if (exec.isEmpty) continue;

          final startupClass = entryMap['StartupWMClass'] ?? entryMap['StartupWmClass'];
          final categories = _splitList(entryMap['Categories']);
          final keywords = _splitList(entryMap['Keywords']);
          final terminal = _parseBool(entryMap['Terminal']);

          results[id] = DesktopApp(
            id: id,
            name: name,
            genericName: genericName,
            comment: comment,
            exec: exec,
            iconKey: entryMap['Icon'],
            startupWmClass: startupClass,
            categories: categories,
            keywords: keywords,
            terminal: terminal,
            desktopFilePath: entity.path,
            rawEntries: entryMap,
          );
        }
      } catch (_) {
        // Ignore directories we cannot access.
        continue;
      }
    }

    return results.values.toList();
  }

  Future<String?> _lookupIcon(String iconName) async {
    String candidate = iconName;
    final home = Platform.environment['HOME'];
    if (candidate.startsWith('~') && home != null) {
      candidate = candidate.replaceFirst('~', home);
    }

    if (candidate.startsWith('/')) {
      final file = File(candidate);
      if (await file.exists()) {
        return file.path;
      }
    }

    if (candidate.contains('/')) {
      // Relative path inside theme directory.
      for (final dir in _iconDirectories) {
        final path = p.normalize(p.join(dir, candidate));
        final file = File(path);
        if (await file.exists()) {
          return file.path;
        }
      }
    }

    await _ensureIconIndex();
    final index = _iconIndex;
    if (index == null || index.isEmpty) return null;

    final baseName = p.basename(candidate).toLowerCase();
    final nameWithoutExt = p.basenameWithoutExtension(candidate).toLowerCase();

    final directMatch = index[baseName];
    if (directMatch != null) return directMatch;

    final extLess = index[nameWithoutExt];
    if (extLess != null) return extLess;

    return null;
  }

  Future<void> _ensureIconIndex() {
    if (_iconIndex != null) {
      return Future<void>.value();
    }
    return _iconIndexFuture ??= _buildIconIndex();
  }

  Future<void> _buildIconIndex() async {
    final Map<String, String> index = <String, String>{};
    final Set<String> allowedExtensions = <String>{'.png', '.svg', '.xpm', '.webp'};

    for (final dirPath in _iconSearchDirectoryPaths) {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) continue;

      try {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is! File && entity is! Link) continue;
          final extension = p.extension(entity.path).toLowerCase();
          if (!allowedExtensions.contains(extension)) continue;

          final base = p.basename(entity.path).toLowerCase();
          final name = p.basenameWithoutExtension(entity.path).toLowerCase();

          index.putIfAbsent(base, () => entity.path);
          index.putIfAbsent(name, () => entity.path);
        }
      } catch (_) {
        // Ignore directories that cannot be read.
        continue;
      }
    }

    _iconIndex = index;
  }

  Future<Map<String, String>> _readDesktopFile(File file) async {
    try {
      final content = await file.readAsString();
      return _parseDesktopFile(content);
    } catch (_) {
      return <String, String>{};
    }
  }

  Map<String, String> _parseDesktopFile(String content) {
    final Map<String, String> entries = <String, String>{};
    final lines = const LineSplitter().convert(content);
    var insideDesktopEntry = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      if (line.startsWith('[')) {
        insideDesktopEntry = line == '[Desktop Entry]';
        continue;
      }

      if (!insideDesktopEntry) continue;

      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) continue;

      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      entries[key] = value;
    }

    return entries;
  }

  bool _isApplicationEntry(Map<String, String> entries) {
    final type = entries['Type'];
    if (type == null) return false;
    return type.toLowerCase() == 'application';
  }

  static bool _parseBool(String? value) {
    if (value == null) return false;
    return value.toLowerCase() == 'true' || value == '1';
  }

  static List<String> _splitList(String? value) {
    if (value == null || value.isEmpty) return const <String>[];
    return value.split(';').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false);
  }

  String? _selectPreferredValue(Map<String, String> entries, String key) {
    // Try English first (en_US, en_GB, en)
    final englishLocales = ['$key[en_US]', '$key[en_GB]', '$key[en]'];
    for (final englishKey in englishLocales) {
      if (entries.containsKey(englishKey)) {
        return entries[englishKey];
      }
    }

    // Fall back to the default (non-localized) value
    return entries[key];
  }

  List<String> get _applicationDirectories {
    if (_applicationDirs != null) return _applicationDirs!;

    final env = Platform.environment;
    final Set<String> directories = LinkedHashSet<String>();

    final home = env['HOME'];
    final dataDirs = env['XDG_DATA_DIRS']?.split(':') ?? <String>['/usr/local/share', '/usr/share'];
    final dataHome = env['XDG_DATA_HOME'] ?? (home != null ? p.join(home, '.local', 'share') : null);

    if (dataHome != null) {
      directories.add(p.join(dataHome, 'applications'));
    }
    if (home != null) {
      directories.add(p.join(home, '.local', 'share', 'applications'));
    }

    for (final dir in dataDirs) {
      if (dir.isEmpty) continue;
      directories.add(p.join(dir, 'applications'));
    }

    // Add Flatpak application directories
    directories.add('/var/lib/flatpak/exports/share/applications');
    if (home != null) {
      directories.add(p.join(home, '.local', 'share', 'flatpak', 'exports', 'share', 'applications'));
    }

    // Add Snap application directories
    directories.add('/var/lib/snapd/desktop/applications');

    _applicationDirs = directories.toList(growable: false);
    return _applicationDirs!;
  }

  List<String> get _iconDirectories {
    if (_iconDirs != null) return _iconDirs!;

    final env = Platform.environment;
    final Set<String> directories = LinkedHashSet<String>();
    final home = env['HOME'];
    final dataDirs = env['XDG_DATA_DIRS']?.split(':') ?? <String>['/usr/local/share', '/usr/share'];
    final dataHome = env['XDG_DATA_HOME'] ?? (home != null ? p.join(home, '.local', 'share') : null);

    if (dataHome != null) {
      directories.add(p.join(dataHome, 'icons'));
    }
    if (home != null) {
      directories.add(p.join(home, '.icons'));
    }

    for (final dir in dataDirs) {
      if (dir.isEmpty) continue;
      directories.add(p.join(dir, 'icons'));
      directories.add(p.join(dir, 'pixmaps'));
    }

    directories
      ..add('/usr/share/icons')
      ..add('/usr/share/pixmaps');

    // Add Flatpak icon directories
    directories.add('/var/lib/flatpak/exports/share/icons');
    if (home != null) {
      directories.add(p.join(home, '.local', 'share', 'flatpak', 'exports', 'share', 'icons'));
    }

    _iconDirs = directories.toList(growable: false);
    return _iconDirs!;
  }

  List<String> get _preferredIconThemes {
    if (_iconThemePreferences != null) {
      return _iconThemePreferences!;
    }

    final LinkedHashSet<String> themes = LinkedHashSet<String>();
    final env = Platform.environment;

    void addTheme(String? value) {
      if (value == null) return;
      final normalized = value.split(':').first.trim();
      if (normalized.isEmpty) return;
      themes.add(normalized);
    }

    addTheme(env['XDG_ICON_THEME']);
    addTheme(env['GTK_THEME']);

    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      addTheme(_readIniValue(p.join(home, '.config', 'gtk-3.0', 'settings.ini'), 'Settings', 'gtk-icon-theme-name'));
      addTheme(_readIniValue(p.join(home, '.config', 'gtk-4.0', 'settings.ini'), 'Settings', 'gtk-icon-theme-name'));
      addTheme(_readGtkRcTheme(p.join(home, '.gtkrc-2.0')));
      addTheme(_readIniValue(p.join(home, '.config', 'kdeglobals'), 'Icons', 'Theme'));
    }

    themes.add('hicolor');
    for (final fallback in const <String>['Adwaita', 'breeze', 'Papirus']) {
      themes.add(fallback);
    }

    _iconThemePreferences = themes.toList(growable: false);
    return _iconThemePreferences!;
  }

  List<String> get _iconThemeOrder {
    if (_iconThemeOrderCache != null) {
      return _iconThemeOrderCache!;
    }

    final LinkedHashSet<String> order = LinkedHashSet<String>();
    final Queue<String> queue = Queue<String>()..addAll(_preferredIconThemes);

    while (queue.isNotEmpty) {
      final theme = queue.removeFirst().trim();
      if (theme.isEmpty) continue;
      if (!order.add(theme)) continue;

      for (final inherited in _themeInheritances(theme)) {
        final normalized = inherited.trim();
        if (normalized.isEmpty) continue;
        queue.add(normalized);
      }
    }

    if (!order.contains('hicolor')) {
      order.add('hicolor');
    }

    _iconThemeOrderCache = order.toList(growable: false);
    return _iconThemeOrderCache!;
  }

  List<String> get _iconSearchDirectoryPaths {
    if (_iconSearchDirectoryPathsCache != null) {
      return _iconSearchDirectoryPathsCache!;
    }

    final LinkedHashSet<String> result = LinkedHashSet<String>();

    for (final theme in _iconThemeOrder) {
      for (final baseDir in _iconDirectories) {
        final themeRoot = p.normalize(p.join(baseDir, theme));
        final directory = Directory(themeRoot);
        if (!directory.existsSync()) continue;

        final parsed = _parseIconThemeIndex(themeRoot);
        final directories = parsed?.directories ?? const <String>[];

        if (directories.isNotEmpty) {
          for (final relative in directories) {
            final resolved = p.normalize(p.join(themeRoot, relative));
            final dir = Directory(resolved);
            if (dir.existsSync()) {
              result.add(dir.path);
            }
          }
        } else {
          try {
            for (final entity in directory.listSync()) {
              if (entity is Directory) {
                result.add(entity.path);
              }
            }
          } catch (_) {
            // Ignore unreadable directories.
          }
        }

        result.add(themeRoot);
      }
    }

    for (final dirPath in _iconDirectories) {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) continue;
      result.add(directory.path);
    }

    _iconSearchDirectoryPathsCache = result.toList(growable: false);
    return _iconSearchDirectoryPathsCache!;
  }

  List<String> _themeInheritances(String themeName) {
    final List<String> inherits = <String>[];
    for (final baseDir in _iconDirectories) {
      final themeRoot = p.normalize(p.join(baseDir, themeName));
      final parsed = _parseIconThemeIndex(themeRoot);
      if (parsed == null) continue;
      inherits.addAll(parsed.inherits);
    }
    return inherits;
  }

  _ParsedIconTheme? _parseIconThemeIndex(String themeRoot) {
    if (_parsedIconThemeCache.containsKey(themeRoot)) {
      return _parsedIconThemeCache[themeRoot];
    }

    final indexFile = File(p.join(themeRoot, 'index.theme'));
    if (!indexFile.existsSync()) {
      _parsedIconThemeCache[themeRoot] = null;
      return null;
    }

    try {
      final lines = indexFile.readAsLinesSync();
      final List<String> directories = <String>[];
      final List<String> inherits = <String>[];
      String? currentSection;

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
          continue;
        }

        if (line.startsWith('[') && line.endsWith(']')) {
          currentSection = line.substring(1, line.length - 1).trim();
          continue;
        }

        if (currentSection == null || !_equalsIgnoreCase(currentSection, 'Icon Theme')) {
          continue;
        }

        final separatorIndex = line.indexOf('=');
        if (separatorIndex == -1) continue;
        final key = line.substring(0, separatorIndex).trim();
        final value = line.substring(separatorIndex + 1).trim();

        if (_equalsIgnoreCase(key, 'Directories')) {
          directories.addAll(value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty));
        } else if (_equalsIgnoreCase(key, 'Inherits')) {
          inherits.addAll(value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty));
        }
      }

      final parsed = _ParsedIconTheme(directories: directories, inherits: inherits);
      _parsedIconThemeCache[themeRoot] = parsed;
      return parsed;
    } catch (_) {
      _parsedIconThemeCache[themeRoot] = null;
      return null;
    }
  }
}

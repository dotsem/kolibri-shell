import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/services/app_catalog.dart';
import 'package:hypr_flutter/services/window_icon_resolver.dart';

/// Represents a launchable application with its icon data.
class LaunchableApp {
  const LaunchableApp({required this.app, required this.iconData});

  final DesktopApp app;
  final WindowIconData iconData;

  /// Returns a searchable string containing all relevant fields.
  String get searchableText {
    final buffer = StringBuffer();
    buffer.write(app.name.toLowerCase());
    if (app.genericName != null) {
      buffer.write(' ${app.genericName!.toLowerCase()}');
    }
    if (app.comment != null) {
      buffer.write(' ${app.comment!.toLowerCase()}');
    }
    for (final keyword in app.keywords) {
      buffer.write(' ${keyword.toLowerCase()}');
    }
    buffer.write(' ${app.exec.toLowerCase()}');
    return buffer.toString();
  }

  /// Checks if this app matches the given search query.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return searchableText.contains(lowerQuery) || app.name.toLowerCase().startsWith(lowerQuery);
  }
}

/// Service for managing the app launcher functionality.
/// Provides searchable list of all runnable applications with their icons.
class AppLauncherService extends ChangeNotifier {
  AppLauncherService._internal();

  static final AppLauncherService _instance = AppLauncherService._internal();
  factory AppLauncherService() => _instance;

  final AppCatalogService _catalog = AppCatalogService();

  bool _initialized = false;
  bool _isLoading = false;
  List<LaunchableApp> _apps = <LaunchableApp>[];
  String _searchQuery = '';
  List<LaunchableApp>? _filteredApps;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  /// Returns the current list of apps (filtered if a search query is active).
  List<LaunchableApp> get apps {
    if (_searchQuery.isEmpty) {
      return _apps;
    }
    return _filteredApps ?? _apps;
  }

  /// Initialize the service by loading all applications.
  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  /// Refresh the list of available applications.
  Future<void> refresh() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Initialize the catalog if needed
      if (!_catalog.isInitialized) {
        await _catalog.initialize();
      } else {
        await _catalog.refresh();
      }

      // Get all applications
      final desktopApps = _catalog.applications;

      // Resolve icons for all apps
      final List<LaunchableApp> launchableApps = [];
      for (final app in desktopApps) {
        // Skip apps that should not be displayed
        if (app.noDisplay) continue;

        // Resolve the icon
        final iconPath = await _catalog.iconPathFor(app);
        final WindowIconData iconData;

        if (iconPath != null && iconPath.isNotEmpty) {
          iconData = WindowIconData.fromPath(iconPath);
        } else {
          iconData = WindowIconData.empty;
        }

        launchableApps.add(LaunchableApp(app: app, iconData: iconData));
      }

      _apps = launchableApps;
      _applyFilter();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the search query and filter applications.
  void search(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query.trim();
    _applyFilter();
    notifyListeners();
  }

  /// Clear the search query.
  void clearSearch() {
    if (_searchQuery.isEmpty) return;

    _searchQuery = '';
    _filteredApps = null;
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredApps = null;
      return;
    }

    final lowerQuery = _searchQuery.toLowerCase();
    final List<LaunchableApp> filtered = [];
    final List<LaunchableApp> startsWithMatches = [];
    final List<LaunchableApp> containsMatches = [];

    for (final app in _apps) {
      final nameLower = app.app.name.toLowerCase();

      if (nameLower.startsWith(lowerQuery)) {
        startsWithMatches.add(app);
      } else if (app.matches(_searchQuery)) {
        containsMatches.add(app);
      }
    }

    // Prioritize apps whose names start with the query
    filtered.addAll(startsWithMatches);
    filtered.addAll(containsMatches);

    _filteredApps = filtered;
  }

  /// Launch an application by executing its command.
  Future<bool> launch(LaunchableApp app) async {
    try {
      final exec = app.app.sanitizedExec;
      if (exec.isEmpty) return false;

      // Parse the command and arguments
      final parts = exec.split(RegExp(r'\s+'));
      if (parts.isEmpty) return false;

      final command = parts.first;
      final args = parts.length > 1 ? parts.sublist(1) : <String>[];

      // Launch the process in detached mode
      await Process.start(command, args, mode: ProcessStartMode.detached);

      return true;
    } catch (e) {
      debugPrint('Failed to launch ${app.app.name}: $e');
      return false;
    }
  }
}

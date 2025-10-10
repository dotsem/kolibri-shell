import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hypr_flutter/services/app_catalog.dart';

class WindowIconData {
  const WindowIconData._({this.iconPath, required this.isSvg});

  final String? iconPath;
  final bool isSvg;

  static const WindowIconData empty = WindowIconData._(iconPath: null, isSvg: false);

  bool get hasIcon => iconPath != null && iconPath!.isNotEmpty;
}

class WindowIconResolver {
  WindowIconResolver._();

  static final WindowIconResolver instance = WindowIconResolver._();

  final AppCatalogService _catalog = AppCatalogService();
  final Map<String, WindowIconData> _cache = <String, WindowIconData>{};
  final Map<String, Future<WindowIconData>> _inFlight = <String, Future<WindowIconData>>{};
  final Map<String, ImageProvider> _imageProviders = <String, ImageProvider>{};

  Future<WindowIconData> resolve(String clientClass) {
    final String normalized = clientClass.trim();
    if (normalized.isEmpty) {
      return Future<WindowIconData>.value(WindowIconData.empty);
    }

    final WindowIconData? cached = _cache[normalized];
    if (cached != null) {
      return Future<WindowIconData>.value(cached);
    }

    final Future<WindowIconData>? pending = _inFlight[normalized];
    if (pending != null) {
      return pending;
    }

    final Future<WindowIconData> future = _loadIcon(normalized);
    _inFlight[normalized] = future;
    future.whenComplete(() => _inFlight.remove(normalized));
    return future;
  }

  Future<WindowIconData> _loadIcon(String clientClass) async {
    if (!_catalog.isInitialized) {
      await _catalog.initialize();
    }

    final String? path = await _catalog.iconPathForStartupClass(clientClass);
    if (path == null || path.isEmpty) {
      _cache[clientClass] = WindowIconData.empty;
      return WindowIconData.empty;
    }

    final File file = File(path);
    if (!file.existsSync()) {
      _cache[clientClass] = WindowIconData.empty;
      return WindowIconData.empty;
    }

    final String lower = path.toLowerCase();
    final bool isSvg = lower.endsWith('.svg') || lower.endsWith('.svgz');

    if (!isSvg && !_imageProviders.containsKey(path)) {
      _imageProviders[path] = FileImage(file);
    }

    final WindowIconData data = WindowIconData._(iconPath: path, isSvg: isSvg);
    _cache[clientClass] = data;
    return data;
  }

  Widget buildIcon(
    WindowIconData data, {
    double size = 20,
    double borderRadius = 12,
    BoxFit fit = BoxFit.contain,
    FilterQuality filterQuality = FilterQuality.high,
    IconData fallbackIcon = Icons.apps,
    Color? fallbackColor,
  }) {
    if (!data.hasIcon) {
      return Icon(fallbackIcon, size: size, color: fallbackColor);
    }

    final String path = data.iconPath!;

    if (data.isSvg) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SvgPicture.file(
          File(path),
          width: size,
          height: size,
          fit: fit,
        ),
      );
    }

    final ImageProvider provider = _imageProviders[path] ?? FileImage(File(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image(
        image: provider,
        width: size,
        height: size,
        fit: fit,
        filterQuality: filterQuality,
      ),
    );
  }
}

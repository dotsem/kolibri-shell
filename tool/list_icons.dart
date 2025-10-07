import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hypr_flutter/services/app_catalog.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final catalog = AppCatalogService();
  await catalog.initialize();

  final apps = catalog.applications;
  final List<_AppIconResult> results = <_AppIconResult>[];

  for (final app in apps) {
    final path = await catalog.iconPathFor(app);
    results.add(_AppIconResult(app: app, iconPath: path));
  }

  results.sort((a, b) => a.app.name.toLowerCase().compareTo(b.app.name.toLowerCase()));

  final resolved = results.where((entry) => entry.iconPath != null).length;
  final missing = results.length - resolved;

  stdout
    ..writeln('Total applications: ${results.length}')
    ..writeln('Icons resolved   : $resolved')
    ..writeln('Icons missing    : $missing')
    ..writeln('');

  stdout.writeln('Resolved icons (sample of ${resolved.clamp(0, 20)}):');
  for (final entry in results.where((r) => r.iconPath != null).take(20)) {
    stdout.writeln('  ${entry.app.name} -> ${entry.iconPath}');
  }

  stdout.writeln('');
  stdout.writeln('Missing icons (sample of ${missing.clamp(0, 20)}):');
  for (final entry in results.where((r) => r.iconPath == null).take(20)) {
    stdout.writeln('  ${entry.app.name} (icon key: ${entry.app.iconKey ?? 'n/a'})');
  }
}

class _AppIconResult {
  const _AppIconResult({required this.app, required this.iconPath});

  final DesktopApp app;
  final String? iconPath;
}

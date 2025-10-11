import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/config.dart' as config;
import 'package:hypr_flutter/services/settings.dart';

class HyprFlutterRunner extends StatefulWidget {
  const HyprFlutterRunner({super.key});

  @override
  State<HyprFlutterRunner> createState() => _HyprFlutterRunnerState();
}

class _HyprFlutterRunnerState extends State<HyprFlutterRunner> {
  bool debug = kDebugMode;
  bool _isReloading = false;
  bool _isCompiling = false;
  bool _isDebugging = false;

  final SettingsService _settings = SettingsService();

  Future<void> _buildAndRunRelease() async {
    if (_isCompiling || _isReloading) {
      return;
    }

    setState(() => _isCompiling = true);

    final String projectDirectory = _resolvePath(config.hyprFlutterPath);

    ProcessResult? buildResult;
    try {
      buildResult = await Process.run('flutter', ['build', 'linux'], workingDirectory: projectDirectory);
    } catch (error, stackTrace) {
      debugPrint('HyprFlutterRunner build error: $error\n$stackTrace');
    }

    if (!mounted) {
      return;
    }

    setState(() => _isCompiling = false);

    if (buildResult == null || buildResult.exitCode != 0) {
      debugPrint('HyprFlutterRunner build failed: exitCode=${buildResult?.exitCode} stderr=${buildResult?.stderr}');
      return;
    }

    final bool scheduled = await _scheduleRestartSequence(exitAfterSchedule: true);
    if (!scheduled && mounted) {
      setState(() => _isReloading = false);
    }
  }

  Future<void> _reloadHyprFlutter() async {
    if (_isReloading || _isCompiling) {
      return;
    }

    final bool scheduled = await _scheduleRestartSequence(exitAfterSchedule: false);
    if (!scheduled && mounted) {
      setState(() => _isReloading = false);
    }
  }

  Future<bool> _scheduleRestartSequence({required bool exitAfterSchedule}) async {
    if (_isReloading) {
      return false;
    }

    setState(() => _isReloading = true);

    final String executablePath = _resolvePath(config.buildPath);
    final File binaryFile = File(executablePath).absolute;

    if (!binaryFile.existsSync()) {
      debugPrint('HyprFlutterRunner restart aborted: binary not found at ${binaryFile.path}');
      if (mounted) {
        setState(() => _isReloading = false);
      }
      return false;
    }

    final String processIdentifier = binaryFile.uri.pathSegments.last;
    final String resolvedExecutablePath = binaryFile.path;

    final String quotedIdentifier = _quoteForShell(processIdentifier);
    final String quotedExecutable = _quoteForShell(resolvedExecutablePath);

    final String command =
        '''
(
  sleep 0.1
  killall -q $quotedIdentifier || true
  sleep 0.2
  $quotedExecutable >/dev/null 2>&1 &
) &
''';

    try {
      await Process.start('sh', ['-c', command], mode: ProcessStartMode.detachedWithStdio);
    } catch (error, stackTrace) {
      debugPrint('HyprFlutterRunner restart scheduling failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _isReloading = false);
      }
      return false;
    }

    if (exitAfterSchedule) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      exit(0);
    } else {
      Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
        if (mounted) {
          setState(() => _isReloading = false);
        }
      });
    }

    return true;
  }

  Future<void> _debugHyprFlutter() async {
    if (_isDebugging || _isCompiling || _isReloading) {
      return;
    }

    setState(() => _isDebugging = true);

    final String projectDirectory = _resolvePath(config.hyprFlutterPath);
    final Map<String, dynamic> storedEditors = jsonDecode(await _settings.getString(SettingsKeys.codeEditors)) as Map<String, dynamic>;
    final Map<String, String> codeEditors = storedEditors.map((key, value) => MapEntry(key, value.toString()));
    final String preferredCodeEditor = await _settings.getString(SettingsKeys.preferredCodeEditor);
    final String? editorExecutable = codeEditors[preferredCodeEditor];
    if (editorExecutable == null) {
      debugPrint('Preferred code editor "$preferredCodeEditor" unavailable. Available keys: ${codeEditors.keys.join(', ')}');
      setState(() => _isDebugging = false);
      return;
    }

    await Process.run(editorExecutable, [projectDirectory]);

    await _terminateAndDiscardBinary();

    setState(() => _isDebugging = false);
  }

  Future<void> _terminateAndDiscardBinary() async {
    final String executablePath = _resolvePath(config.buildPath);
    final File binaryFile = File(executablePath).absolute;

    if (!binaryFile.existsSync()) {
      return;
    }

    final String processIdentifier = binaryFile.uri.pathSegments.last;

    try {
      await Process.run('killall', ['-q', processIdentifier]);
    } catch (error) {
      debugPrint('HyprFlutterRunner killall failed (ignored): $error');
    }

    try {
      await binaryFile.delete();
    } catch (error) {
      debugPrint('HyprFlutterRunner failed to delete binary (ignored): $error');
    }
  }

  String _resolvePath(String path) {
    if (path.startsWith('~')) {
      final String? home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return path.replaceFirst('~', home);
      }
    }
    return path;
  }

  String _quoteForShell(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  @override
  Widget build(BuildContext context) {
    return debug
        ? ElevatedButton(
            onPressed: (_isCompiling || _isReloading) ? null : _buildAndRunRelease,
            child: (_isCompiling || _isReloading) ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Build & Run'),
          )
        : Row(
            children: [
              IconButton(
                tooltip: "Reload Shell",
                onPressed: (_isReloading || _isCompiling) ? null : _reloadHyprFlutter,
                icon: _isReloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: "Start Developing",
                onPressed: (_isReloading || _isCompiling || _isDebugging) ? null : _debugHyprFlutter,
                icon: _isDebugging ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bug_report),
              ),
            ],
          );
  }
}

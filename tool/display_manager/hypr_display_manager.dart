import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:hypr_flutter/models/display_layout.dart';
import 'package:hypr_flutter/services/display_layout_store.dart';
import 'package:hypr_flutter/services/display_manager.dart';

Future<void> main(List<String> arguments) async {
  final bool watch = arguments.contains('--watch');
  final String? layoutId = _parseApplyArgument(arguments);

  final DisplayManagerService service = DisplayManagerService();
  final DisplayLayoutStore store = DisplayLayoutStore();

  ProcessSignal.sigterm.watch().listen((_) async {
    await _shutdown(service, store);
    exit(0);
  });
  ProcessSignal.sigint.watch().listen((_) async {
    await _shutdown(service, store);
    exit(0);
  });

  try {
    await service.initialize();

    if (layoutId != null) {
      await service.applyLayoutById(layoutId);
      debugPrint('Applied layout "$layoutId".');
    } else if (service.lastAppliedLayout != null) {
      await service.applyLayout(service.lastAppliedLayout!, persistLastApplied: false);
      debugPrint('Re-applied last layout "${service.lastAppliedLayout!.id}".');
    } else if (service.layouts.isNotEmpty) {
      final DisplayLayout first = service.layouts.first;
      await service.applyLayout(first, persistLastApplied: false);
      debugPrint('Applied default layout "${first.id}".');
    } else {
      final DisplayLayout snapshot = await service.snapshotCurrentLayout(id: 'initial_snapshot', label: 'Current setup');
      await service.saveLayout(snapshot, setAsLastApplied: true);
      debugPrint('Captured current monitor configuration as "${snapshot.id}".');
    }

    if (!watch) {
      await _shutdown(service, store);
      return;
    }

    debugPrint('Entering watch mode. Listening for layout changes...');
    String? appliedId = service.lastAppliedLayout?.id;
    service.addListener(() {
      appliedId = service.lastAppliedLayout?.id ?? appliedId;
    });

    store.stream.listen((DisplayLayoutsBundle bundle) async {
      final String? targetId = bundle.lastAppliedLayoutId;
      if (targetId == null || targetId == appliedId) {
        return;
      }

      DisplayLayout? layout;
      for (final DisplayLayout item in bundle.layouts) {
        if (item.id == targetId) {
          layout = item;
          break;
        }
      }
      if (layout == null) {
        debugPrint('Layout "$targetId" referenced by lastAppliedLayoutId but not found.');
        return;
      }

      try {
        await service.applyLayout(layout, persistLastApplied: false);
        appliedId = layout.id;
        debugPrint('Applied layout "$targetId" from watch update.');
      } catch (error, stackTrace) {
        debugPrint('Failed to apply watched layout "$targetId": $error');
        debugPrint(stackTrace.toString());
      }
    });

    final Completer<void> completer = Completer<void>();
    await completer.future;
  } catch (error, stackTrace) {
    stderr.writeln('hypr_display_manager error: $error');
    stderr.writeln(stackTrace);
    await _shutdown(service, store);
    exit(1);
  }
}

String? _parseApplyArgument(List<String> arguments) {
  for (int i = 0; i < arguments.length; i++) {
    final String arg = arguments[i];
    if (arg == '--apply' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
    if (arg.startsWith('--apply=')) {
      return arg.substring('--apply='.length);
    }
  }
  return null;
}

Future<void> _shutdown(DisplayManagerService service, DisplayLayoutStore store) async {
  try {
    service.dispose();
  } catch (_) {}
  try {
    await store.dispose();
  } catch (_) {}
}

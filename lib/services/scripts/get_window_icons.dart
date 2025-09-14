import 'dart:convert';
import 'dart:io';

class WindowIcon {
  final int workspaceId;
  final String iconPath;

  WindowIcon({required this.workspaceId, required this.iconPath});

  factory WindowIcon.fromJson(Map<String, dynamic> json) {
    return WindowIcon(workspaceId: json['workspace_id'], iconPath: json['icon_path']);
  }

  Map<String, dynamic> toJson() {
    return {'workspace_id': workspaceId, 'icon_path': iconPath};
  }
}

Future<List<WindowIcon>> getHyprlandWindows() async {
  try {
    // Get window information from hyprctl
    final result = await Process.run('hyprctl', ['clients', '-j']);

    if (result.exitCode != 0) {
      throw Exception('hyprctl failed: ${result.stderr}');
    }

    final jsonData = json.decode(result.stdout as String) as List<dynamic>;
    final windowIcons = <WindowIcon>[];

    for (final window in jsonData) {
      final mapped = window['mapped'] as bool;
      if (!mapped) continue;

      final workspaceId = window['workspace']['id'] as int;
      final windowClass = window['class'] as String;

      // Try to find icon using various methods
      final iconPath = await findIconForClass(windowClass);

      if (iconPath.isNotEmpty) {
        windowIcons.add(WindowIcon(workspaceId: workspaceId, iconPath: iconPath));
      }
    }

    return windowIcons;
  } catch (e) {
    throw Exception('Failed to get hyprland windows: $e');
  }
}

Future<String> findIconForClass(String windowClass) async {
  // Common icon directories
  final iconDirs = [
    '/usr/share/icons',
    '/usr/share/pixmaps',
    '${Platform.environment['HOME']}/.local/share/icons',
    '${Platform.environment['HOME']}/.icons',
  ];

  // Try to find icon by class name
  for (final dir in iconDirs) {
    final dirFile = Directory(dir);
    if (await dirFile.exists()) {
      try {
        final result = await Process.run('find', [
          dir,
          '-name',
          '*$windowClass*',
          '-type',
          'f',
          '(',
          '-iname',
          '*.png',
          '-o',
          '-iname',
          '*.svg',
          ')',
        ]);

        if (result.stdout.toString().isNotEmpty) {
          final paths = result.stdout.toString().split('\n');
          for (final path in paths) {
            if (path.trim().isNotEmpty) {
              return path.trim();
            }
          }
        }
      } catch (e) {
        // Continue to next directory if find fails
        continue;
      }
    }
  }

  return '';
}

void main() async {
  try {
    print('Fetching Hyprland window information...');

    final windowIcons = await getHyprlandWindows();

    if (windowIcons.isEmpty) {
      print('No windows with icons found.');
      return;
    }

    // Output as JSON
    final jsonOutput = json.encode(windowIcons.map((icon) => icon.toJson()).toList());

    print(jsonOutput);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

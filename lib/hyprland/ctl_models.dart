class Workspace {
  final int id;
  final String name;
  final String monitor;
  final int monitorId;
  final int windows;
  final bool hasFullscreen;
  final String lastWindow;
  final String lastWindowTitle;
  final bool isPersistent;

  // Workspace({
  //   required this.id,
  //   required this.name,
  //   required this.monitor,
  //   required this.monitorId,
  //   required this.windows,
  //   required this.hasFullscreen,
  //   required this.lastWindow,
  //   required this.lastWindowTitle,
  //   required this.isPersistent,
  // });

  Workspace.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      monitor = json['monitor'] as String,
      monitorId = json['monitorID'] as int,
      windows = json['windows'] as int,
      hasFullscreen = json['hasfullscreen'] as bool,
      lastWindow = json['lastwindow'] as String,
      lastWindowTitle = json['lastwindowtitle'] as String,
      isPersistent = json['ispersistent'] as bool;
}

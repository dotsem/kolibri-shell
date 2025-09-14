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

class Monitor {
  int id;
  String name;
  String desciprtion;
  String model;
  String serial;
  int width;
  int height;
  double refreshRate;
  int x;
  int y;
  Map<String, dynamic> activeWorkspace;
  Map<String, dynamic> specialWorkspace;
  List<int> reserved;
  double scale;
  int transform;
  bool focused;
  bool dpmsStatus;
  bool vrr;
  String solitary;
  bool activelyTearing;
  String directScanoutTo;
  bool disabled;
  String currentFormat;
  String mirrorOf;
  List<String> availableModes;

  Monitor.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      desciprtion = json['description'] as String,
      model = json['model'] as String,
      serial = json['serial'] as String,
      width = json['width'] as int,
      height = json['height'] as int,
      refreshRate = json['refreshRate'] as double,
      x = json['x'] as int,
      y = json['y'] as int,
      activeWorkspace = json['activeWorkspace'] as Map<String, dynamic>,
      specialWorkspace = json['specialWorkspace'] as Map<String, dynamic>,
      reserved = List<int>.from(json['reserved']),
      scale = json['scale'] as double,
      transform = json['transform'] as int,
      focused = json['focused'] as bool,
      dpmsStatus = json['dpmsStatus'] as bool,
      vrr = json['vrr'] as bool,
      solitary = json['solitary'] as String,
      activelyTearing = json['activelyTearing'] as bool,
      directScanoutTo = json['directScanoutTo'] as String,
      disabled = json['disabled'] as bool,
      currentFormat = json['currentFormat'] as String,
      mirrorOf = json['mirrorOf'] as String,
      availableModes = List<String>.from(json['availableModes']);
}

class Client {
  String adress;
  bool mapped;
  bool hidden;
  List<int> at;
  List<int> size;
  Map<String, dynamic> workspace;
  bool floating;
  bool pseudo;
  int monitor;
  String clientClass;
  String title;
  String initialClass;
  String initialTitle;
  int pid;
  bool xwayland;
  bool pinned;
  int fullscreen;
  int fullscreenClient;
  List grouped;
  List tags;
  String swallowing;
  int focusHistoryId;
  bool inhibitingIdle;
  String xdgTag;
  String xdgDescription;

  Client.fromJson(Map<String, dynamic> json)
    : adress = json['address'] as String,
      mapped = json['mapped'] as bool,
      hidden = json['hidden'] as bool,
      at = List<int>.from(json['at']),
      size = List<int>.from(json['size']),
      workspace = json['workspace'] as Map<String, dynamic>,
      floating = json['floating'] as bool,
      pseudo = json['pseudo'] as bool,
      monitor = json['monitor'] as int,
      clientClass = json['class'] as String,
      title = json['title'] as String,
      initialClass = json['initialClass'] as String,
      initialTitle = json['initialTitle'] as String,
      pid = json['pid'] as int,
      xwayland = json['xwayland'] as bool,
      pinned = json['pinned'] as bool,
      fullscreen = json['fullscreen'] as int,
      fullscreenClient = json['fullscreenClient'] as int,
      grouped = List.from(json['grouped']),
      tags = List.from(json['tags']),
      swallowing = json['swallowing'] as String,
      focusHistoryId = json['focusHistoryID'] as int,
      inhibitingIdle = json['inhibitingIdle'] as bool,
      xdgTag = json['xdgTag'] as String,
      xdgDescription = json['xdgDescription'] as String;
}

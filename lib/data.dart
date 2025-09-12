import 'package:flutter/services.dart';
import 'package:hypr_flutter/hyprland/ctl.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';

MethodChannel sharedChannel = MethodChannel('shell_communication');
List<String> initialArgs = [];
HyprlandCtl hyprCtl = HyprlandCtl();

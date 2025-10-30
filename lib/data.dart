import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hypr_flutter/hyprland/ctl.dart';
import 'package:hypr_flutter/hyprland/ipc.dart';

// Global shared channel for IPC between windows
MethodChannel sharedChannel = MethodChannel('shell_communication');
List<String> initialArgs = [];

// Hyprland integration singletons
HyprlandCtl hyprCtl = HyprlandCtl();
HyprlandIpcManager hyprIpc = HyprlandIpcManager.instance;

const int musicPlayerWidth = 300;
const int taskbarHeight = 48;

// Note: Each isolate (window) has its own copy of these variables
// Services are initialized per-isolate, not globally

// System service singletons (lazy-loaded, only initialized when accessed)
// Access via ClockService(), BluetoothService(), etc. - the factory pattern ensures singleton behavior

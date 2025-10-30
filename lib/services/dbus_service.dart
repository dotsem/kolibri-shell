import 'package:dbus/dbus.dart';
import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:hypr_flutter/services/appearance.dart';
import 'package:hypr_flutter/services/clock.dart';
import 'package:hypr_flutter/window_ids.dart';

/// DBus service for controlling the Hypr Flutter panels.
/// Exposes methods to show, hide, and toggle panels via DBus.
class HyprPanelDBusService {
  HyprPanelDBusService._();

  static final HyprPanelDBusService instance = HyprPanelDBusService._();

  DBusClient? _client;
  bool _isRegistered = false;

  static const String busName = 'com.hyprflutter.Panel';
  static const String objectPath = '/com/hyprflutter/Panel';
  static const String interfaceName = 'com.hyprflutter.Panel';

  /// Initialize and register the DBus service.
  Future<void> initialize() async {
    if (_isRegistered) return;

    try {
      _client = DBusClient.session();

      // Request the bus name
      final result = await _client!.requestName(busName, flags: {DBusRequestNameFlag.doNotQueue});

      if (result == DBusRequestNameReply.primaryOwner) {
        // Register our object
        final panelInterface = _PanelInterface();
        await _client!.registerObject(panelInterface);
        _isRegistered = true;
        debugPrint('✓ DBus service registered: $busName');
      } else {
        debugPrint('✗ Failed to register DBus service: $busName');
      }
    } catch (e) {
      debugPrint('✗ Error initializing DBus service: $e');
    }
  }

  /// Dispose of the DBus connection.
  Future<void> dispose() async {
    if (_client != null) {
      await _client!.releaseName(busName);
      await _client!.close();
      _client = null;
      _isRegistered = false;
    }
  }

  bool get isRegistered => _isRegistered;
}

/// DBus object that implements the panel control interface.
class _PanelInterface extends DBusObject {
  _PanelInterface() : super(DBusObjectPath(HyprPanelDBusService.objectPath));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != HyprPanelDBusService.interfaceName) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    try {
      // Generic Execute method that handles all commands
      if (methodCall.name == 'Execute') {
        return await _executeCommand(methodCall);
      }

      // Legacy methods for backwards compatibility
      switch (methodCall.name) {
        case 'ShowPanel':
          return await _showPanel(methodCall);
        case 'HidePanel':
          return await _hidePanel(methodCall);
        case 'TogglePanel':
          return await _togglePanel(methodCall);
        case 'ShowMenu':
          return await _showMenu(methodCall);
        case 'HideMenu':
          return await _hideMenu(methodCall);
        case 'ToggleMenu':
          return await _toggleMenu(methodCall);
        case 'ListPanels':
          return _listPanels(methodCall);
        case 'GetHelp':
          return _getHelp(methodCall);
        case 'Ping':
          return DBusMethodSuccessResponse([const DBusString('pong')]);
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    } catch (e) {
      return DBusMethodErrorResponse.failed(e.toString());
    }
  }

  /// Generic command executor that parses command strings
  Future<DBusMethodResponse> _executeCommand(DBusMethodCall methodCall) async {
    if (methodCall.values.isEmpty || methodCall.values[0] is! DBusString) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final command = (methodCall.values[0] as DBusString).value;
    final parts = command.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final action = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];
    try {
      switch (action) {
        case 'menu':
        case 'toggle-menu':
          return await _toggleMenu(methodCall);

        case 'show-menu':
          return await _showMenu(methodCall);

        case 'hide-menu':
          return await _hideMenu(methodCall);

        case 'reload-appearance':
        case 'reload-theme':
          return await _reloadAppearance();

        case 'show':
          if (args.isEmpty) {
            return DBusMethodErrorResponse.invalidArgs('Missing panel ID for show command');
          }
          return await _showPanelById(args[0]);

        case 'hide':
          if (args.isEmpty) {
            return DBusMethodErrorResponse.invalidArgs('Missing panel ID for hide command');
          }
          return await _hidePanelById(args[0]);

        case 'toggle':
          if (args.isEmpty) {
            return DBusMethodErrorResponse.invalidArgs('Missing panel ID for toggle command');
          }
          return await _togglePanelById(args[0]);

        case 'list':
        case 'list-panels':
          return _listPanels(methodCall);

        case 'help':
          return _getHelp(methodCall);

        case 'ping':
          return DBusMethodSuccessResponse([const DBusString('pong')]);

        default:
          return DBusMethodErrorResponse.invalidArgs('Unknown command: $action');
      }
    } catch (e) {
      return DBusMethodErrorResponse.failed(e.toString());
    }
  }

  Future<DBusMethodResponse> _reloadAppearance() async {
    try {
      debugPrint('[DBus] Reloading appearance configuration...');
      await AppearanceService().reload();

      // Trigger clock service to reload as well
      // The clock will pick up the new showSeconds setting on next initialization
      final clockService = ClockService();
      clockService.dispose();
      clockService.initialize();

      debugPrint('[DBus] ✓ Appearance reloaded successfully');
      return DBusMethodSuccessResponse([const DBusString('Appearance reloaded')]);
    } catch (e) {
      debugPrint('[DBus] ✗ Failed to reload appearance: $e');
      return DBusMethodErrorResponse.failed('Failed to reload appearance: $e');
    }
  }

  Future<DBusMethodResponse> _showPanelById(String panelId) async {
    try {
      await FlLinuxWindowManager.instance.showWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to show panel: $e');
    }
  }

  Future<DBusMethodResponse> _hidePanelById(String panelId) async {
    try {
      await FlLinuxWindowManager.instance.hideWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to hide panel: $e');
    }
  }

  Future<DBusMethodResponse> _togglePanelById(String panelId) async {
    try {
      if (await FlLinuxWindowManager.instance.isVisible(windowId: panelId)) {
        await FlLinuxWindowManager.instance.hideWindow(windowId: panelId);
      } else {
        await FlLinuxWindowManager.instance.showWindow(windowId: panelId);
      }

      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to toggle panel: $e');
    }
  }

  DBusMethodResponse _getHelp(DBusMethodCall methodCall) {
    const help = '''
Available commands:
  menu, toggle-menu     Toggle the app launcher menu
  show-menu             Show the app launcher menu
  hide-menu             Hide the app launcher menu
  show <panel-id>       Show a specific panel
  hide <panel-id>       Hide a specific panel
  toggle <panel-id>     Toggle a specific panel
  reload-appearance     Reload appearance/theme configuration
  reload-theme          Alias for reload-appearance
  list, list-panels     List all available panels
  help                  Show this help message
  ping                  Check if service is running

Available panel IDs:
  menu              App launcher menu
  left_sidebar      Left sidebar
  right_sidebar     Right sidebar
  music_player      Music player
  settings          Settings panel

Examples:
  menu                    # Toggle menu
  show left_sidebar       # Show left sidebar
  toggle right_sidebar    # Toggle right sidebar
  reload-appearance       # Reload theme from config file
  list                    # List all panels
''';

    return DBusMethodSuccessResponse([const DBusString(help)]);
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        HyprPanelDBusService.interfaceName,
        methods: [
          // Primary method - generic command executor
          DBusIntrospectMethod('Execute', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'command')]),
          // Legacy methods for backwards compatibility
          DBusIntrospectMethod('ShowPanel', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel')]),
          DBusIntrospectMethod('HidePanel', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel')]),
          DBusIntrospectMethod('TogglePanel', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel')]),
          DBusIntrospectMethod('ShowMenu'),
          DBusIntrospectMethod('HideMenu'),
          DBusIntrospectMethod('ToggleMenu'),
          DBusIntrospectMethod('ReloadAppearance', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'result')]),
          DBusIntrospectMethod('ListPanels', args: [DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out, name: 'panels')]),
          DBusIntrospectMethod('GetHelp', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'help')]),
          DBusIntrospectMethod('Ping', args: [DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'response')]),
        ],
      ),
    ];
  }

  Future<DBusMethodResponse> _showPanel(DBusMethodCall methodCall) async {
    if (methodCall.values.isEmpty || methodCall.values[0] is! DBusString) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final panelId = (methodCall.values[0] as DBusString).value;

    try {
      await FlLinuxWindowManager.instance.showWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to show panel: $e');
    }
  }

  Future<DBusMethodResponse> _hidePanel(DBusMethodCall methodCall) async {
    if (methodCall.values.isEmpty || methodCall.values[0] is! DBusString) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final panelId = (methodCall.values[0] as DBusString).value;

    try {
      await FlLinuxWindowManager.instance.hideWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to hide panel: $e');
    }
  }

  Future<DBusMethodResponse> _togglePanel(DBusMethodCall methodCall) async {
    if (methodCall.values.isEmpty || methodCall.values[0] is! DBusString) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final panelId = (methodCall.values[0] as DBusString).value;

    if (await FlLinuxWindowManager.instance.isVisible(windowId: panelId)) {
      await FlLinuxWindowManager.instance.hideWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    } else {
      await FlLinuxWindowManager.instance.showWindow(windowId: panelId);
      return DBusMethodSuccessResponse();
    }
  }

  Future<DBusMethodResponse> _showMenu(DBusMethodCall methodCall) async {
    try {
      await FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.menu);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to show menu: $e');
    }
  }

  Future<DBusMethodResponse> _hideMenu(DBusMethodCall methodCall) async {
    try {
      await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to hide menu: $e');
    }
  }

  Future<DBusMethodResponse> _toggleMenu(DBusMethodCall methodCall) async {
    if (await FlLinuxWindowManager.instance.isVisible(windowId: WindowIds.menu)) {
      await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
      return DBusMethodSuccessResponse();
    } else {
      await FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.menu);
      return DBusMethodSuccessResponse();
    }
  }

  DBusMethodResponse _listPanels(DBusMethodCall methodCall) {
    final panels = [WindowIds.menu, WindowIds.leftSidebar, WindowIds.rightSidebar, WindowIds.musicPlayer, ...WindowIds.taskbars];
    return DBusMethodSuccessResponse([DBusArray.string(panels)]);
  }
}

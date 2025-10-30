import 'package:dbus/dbus.dart';
import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/services/appearance.dart';
import 'package:hypr_flutter/services/clock.dart';
import 'package:hypr_flutter/services/menu_service.dart';
import 'package:hypr_flutter/window_ids.dart';

void _log(String message) {
  if (kDebugMode) {
    print('[DBus Service] $message');
  }
}

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
    _log('===== DBus command received: "$command" =====');
    final parts = command.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) {
      return DBusMethodErrorResponse.invalidArgs();
    }

    final action = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];
    _log('Action: "$action", Args: $args');
    try {
      switch (action) {
        case 'menu':
        case 'toggle-menu':
          // Default to global menu
          final menuType = args.isNotEmpty ? args[0] : 'global';
          _log('>>> Calling _toggleMenuWithType with: "$menuType"');
          return await _toggleMenuWithType(menuType);

        case 'show-menu':
          final menuType = args.isNotEmpty ? args[0] : 'global';
          _log('>>> Calling _showMenuWithType with: "$menuType"');
          return await _showMenuWithType(menuType);

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
  menu [type]           Toggle the menu (types: global, apps, power)
  toggle-menu [type]    Toggle the menu with specific type
  show-menu [type]      Show the menu with specific type
  hide-menu             Hide the menu
  show <panel-id>       Show a specific panel
  hide <panel-id>       Hide a specific panel
  toggle <panel-id>     Toggle a specific panel
  reload-appearance     Reload appearance/theme configuration
  reload-theme          Alias for reload-appearance
  list, list-panels     List all available panels
  help                  Show this help message
  ping                  Check if service is running

Menu types:
  global                Main menu (default)
  apps, applications    Applications launcher
  power                 Power options (lock, logout, shutdown, etc.)

Available panel IDs:
  menu              Menu panel
  left_sidebar      Left sidebar
  right_sidebar     Right sidebar
  music_player      Music player
  settings          Settings panel

Examples:
  menu                    # Toggle global menu
  menu apps               # Toggle apps menu directly
  menu power              # Toggle power menu directly
  show-menu               # Show global menu
  show-menu apps          # Show applications menu
  show-menu power         # Show power menu
  hide-menu               # Hide menu
  show left_sidebar       # Show left sidebar
  toggle right_sidebar    # Toggle right sidebar
  reload-appearance       # Reload theme from config file
  list                    # List all panels

Keybinding examples (add to hyprland.conf):
  bind = SUPER, D, exec, hypr-panel-ctl menu               # Global menu
  bind = SUPER, A, exec, hypr-panel-ctl show-menu apps     # Apps launcher
  bind = SUPER SHIFT, P, exec, hypr-panel-ctl show-menu power  # Power menu
  bind = SUPER, L, exec, hyprlock                          # Direct lock (bypasses menu)
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
          DBusIntrospectMethod(
            'Execute',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.in_,
                name: 'command',
              ),
            ],
          ),
          // Legacy methods for backwards compatibility
          DBusIntrospectMethod(
            'ShowPanel',
            args: [
              DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel'),
            ],
          ),
          DBusIntrospectMethod(
            'HidePanel',
            args: [
              DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel'),
            ],
          ),
          DBusIntrospectMethod(
            'TogglePanel',
            args: [
              DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'panel'),
            ],
          ),
          DBusIntrospectMethod('ShowMenu'),
          DBusIntrospectMethod('HideMenu'),
          DBusIntrospectMethod('ToggleMenu'),
          DBusIntrospectMethod(
            'ReloadAppearance',
            args: [
              DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'result'),
            ],
          ),
          DBusIntrospectMethod(
            'ListPanels',
            args: [
              DBusIntrospectArgument(
                DBusSignature('as'),
                DBusArgumentDirection.out,
                name: 'panels',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'GetHelp',
            args: [
              DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'help'),
            ],
          ),
          DBusIntrospectMethod(
            'Ping',
            args: [
              DBusIntrospectArgument(
                DBusSignature('s'),
                DBusArgumentDirection.out,
                name: 'response',
              ),
            ],
          ),
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

  Future<DBusMethodResponse> _showMenuWithType(String menuType) async {
    try {
      _log('_showMenuWithType called with: "$menuType"');

      final targetType = _getMenuType(menuType);
      _log('Setting menu to type: $targetType');

      // Show the window first
      await FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.menu);
      _log('Menu window shown');

      // Send message to the menu window to change its type
      // The menu window runs in a separate isolate, so we need to use the shared channel
      await _sendMessageToWindow(WindowIds.menu, 'set_menu_type', menuType);
      _log('Sent set_menu_type message to menu window');

      return DBusMethodSuccessResponse();
    } catch (e) {
      _log('ERROR in _showMenuWithType: $e');
      return DBusMethodErrorResponse.failed('Failed to show menu: $e');
    }
  }

  Future<void> _sendMessageToWindow(String windowId, String method, dynamic args) async {
    const shellCom = MethodChannel('shell_communication');
    try {
      await shellCom.invokeMethod(method, {'targetWindow': windowId, 'data': args});
    } catch (e) {
      _log('Error sending message to window $windowId: $e');
    }
  }

  Future<DBusMethodResponse> _toggleMenuWithType(String menuType) async {
    try {
      _log('_toggleMenuWithType called with: "$menuType"');
      final isVisible = await FlLinuxWindowManager.instance.isVisible(windowId: WindowIds.menu);
      _log('Menu visible: $isVisible');

      if (isVisible) {
        // If menu is visible, check if we're requesting the same type
        final menuService = MenuService();
        final requestedType = _getMenuType(menuType);
        _log('Current menu: ${menuService.currentMenu}, Requested: $requestedType');

        if (menuService.currentMenu == requestedType) {
          // Same type - toggle off (hide)
          await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
          menuService.reset(); // Reset to global
        } else {
          // Different type - switch to it
          menuService.navigateTo(requestedType);
        }
      } else {
        // Menu not visible - show with requested type
        return await _showMenuWithType(menuType);
      }
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to toggle menu: $e');
    }
  }

  MenuType _getMenuType(String menuType) {
    _log('_getMenuType called with: "$menuType"');
    final normalized = menuType.toLowerCase().trim();
    _log('Normalized to: "$normalized"');

    switch (normalized) {
      case 'apps':
      case 'applications':
        _log('Returning MenuType.apps');
        return MenuType.apps;
      case 'power':
        _log('Returning MenuType.power');
        return MenuType.power;
      case 'global':
      default:
        _log('Returning MenuType.global (default for "$normalized")');
        return MenuType.global;
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
      // Reset to global menu when hidden for consistent UX
      MenuService().reset();
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to hide menu: $e');
    }
  }

  Future<DBusMethodResponse> _toggleMenu(DBusMethodCall methodCall) async {
    try {
      if (await FlLinuxWindowManager.instance.isVisible(windowId: WindowIds.menu)) {
        await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
        MenuService().reset();
      } else {
        await FlLinuxWindowManager.instance.showWindow(windowId: WindowIds.menu);
      }
      return DBusMethodSuccessResponse();
    } catch (e) {
      return DBusMethodErrorResponse.failed('Failed to toggle menu: $e');
    }
  }

  DBusMethodResponse _listPanels(DBusMethodCall methodCall) {
    final panels = [
      WindowIds.menu,
      WindowIds.leftSidebar,
      WindowIds.rightSidebar,
      WindowIds.musicPlayer,
      ...WindowIds.taskbars,
    ];
    return DBusMethodSuccessResponse([DBusArray.string(panels)]);
  }
}

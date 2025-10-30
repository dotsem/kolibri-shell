import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/panels/menu/app_launcher.dart';
import 'package:hypr_flutter/panels/menu/global_menu.dart';
import 'package:hypr_flutter/panels/menu/power_menu.dart';
import 'package:hypr_flutter/services/menu_service.dart';

class MenuPanel extends StatefulWidget {
  const MenuPanel({super.key});

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  final MenuService _menuService = MenuService();
  final MethodChannel _shellCom = const MethodChannel('shell_communication');

  @override
  void initState() {
    super.initState();

    // Listen for messages from other windows (like DBus service in main window)
    _shellCom.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'set_menu_type':
        final menuTypeStr = call.arguments['data'] as String?;
        if (menuTypeStr != null) {
          final menuType = _parseMenuType(menuTypeStr);
          _menuService.navigateTo(menuType);
        }
        break;
    }
  }

  MenuType _parseMenuType(String menuType) {
    final normalized = menuType.toLowerCase().trim();
    switch (normalized) {
      case 'apps':
      case 'applications':
        return MenuType.apps;
      case 'power':
        return MenuType.power;
      case 'global':
      default:
        return MenuType.global;
    }
  }

  @override
  void dispose() {
    _shellCom.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListenableBuilder(
              listenable: _menuService,
              builder: (context, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCurrentMenu(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentMenu() {
    switch (_menuService.currentMenu) {
      case MenuType.global:
        return const GlobalMenu(key: ValueKey('global'));
      case MenuType.apps:
        return const AppLauncher(key: ValueKey('apps'));
      case MenuType.power:
        return const PowerMenu(key: ValueKey('power'));
    }
  }
}

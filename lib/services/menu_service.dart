import 'package:flutter/foundation.dart';

enum MenuType { global, apps, power }

/// Service to manage menu navigation and state
class MenuService extends ChangeNotifier {
  static final MenuService _instance = MenuService._internal();
  factory MenuService() {
    return _instance;
  }
  MenuService._internal();

  MenuType _currentMenu = MenuType.global;

  MenuType get currentMenu => _currentMenu;

  void navigateTo(MenuType menu) {
    if (menu != _currentMenu) {
      _currentMenu = menu;
      notifyListeners();
    }
  }

  void reset() {
    _currentMenu = MenuType.global;
    notifyListeners();
  }
}

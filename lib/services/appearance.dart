import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/windows/settings/settings_models.dart';

ThemeData buildAppearanceTheme({
  required bool darkModeEnabled,
  required Color primaryColor,
  required Color accentColor,
  required Color backgroundColor,
  required Color containerColor,
}) {
  final Brightness brightness = darkModeEnabled ? Brightness.dark : Brightness.light;
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: primaryColor, brightness: brightness).copyWith(
    primary: primaryColor,
    secondary: accentColor,
    surface: containerColor,
    surfaceTint: Colors.transparent,
    background: backgroundColor,
    onSurface: _contrastingColor(containerColor),
    onSurfaceVariant: _contrastingColor(containerColor).withOpacity(0.7),
    onBackground: _contrastingColor(backgroundColor),
    onPrimary: _contrastingColor(primaryColor),
    onSecondary: _contrastingColor(accentColor),
  );

  final TextTheme baseText = ThemeData(brightness: brightness).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: backgroundColor,
    canvasColor: backgroundColor,
    cardColor: containerColor,
    textTheme: baseText.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: containerColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      titleTextStyle: baseText.titleLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: containerColor.withOpacity(brightness == Brightness.dark ? 0.65 : 0.9),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.onSurface),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: _contrastingColor(scheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurfaceVariant.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurface,
      subtitleTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withOpacity(0.2),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withOpacity(0.12),
      valueIndicatorColor: scheme.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? scheme.primary : scheme.onSurfaceVariant.withOpacity(0.3)),
      checkColor: MaterialStateProperty.all<Color>(_contrastingColor(scheme.primary)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
      trackColor: MaterialStateProperty.resolveWith((states) =>
          states.contains(MaterialState.selected) ? scheme.primary.withOpacity(0.45) : scheme.onSurface.withOpacity(0.12)),
    ),
    dividerTheme: DividerThemeData(color: scheme.onSurfaceVariant.withOpacity(0.2)),
  );
}

class AppearanceService extends ChangeNotifier {
  AppearanceService._internal();

  static final AppearanceService _instance = AppearanceService._internal();
  factory AppearanceService() => _instance;

  final SettingsService _settings = SettingsService();

  bool _isLoaded = false;
  bool _loading = false;

  bool _darkModeEnabled = true;
  bool _enableBlur = true;
  Color _primaryColor = const Color(0xFF1E88E5);
  Color _accentColor = const Color(0xFFFFB300);
  Color _backgroundColor = const Color(0xFF121212);
  Color _containerColor = const Color(0xFF1F1F1F);
  double _taskbarOpacity = 0.9;
  bool _showSecondsOnClock = false;
  NavbarPosition _navbarPosition = NavbarPosition.top;

  bool get isLoaded => _isLoaded;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get enableBlur => _enableBlur;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  Color get backgroundColor => _backgroundColor;
  Color get containerColor => _containerColor;
  double get taskbarOpacity => _taskbarOpacity;
  bool get showSecondsOnClock => _showSecondsOnClock;
  NavbarPosition get navbarPosition => _navbarPosition;

  ThemeData get themeData => buildAppearanceTheme(
        darkModeEnabled: _darkModeEnabled,
        primaryColor: _primaryColor,
        accentColor: _accentColor,
        backgroundColor: _backgroundColor,
        containerColor: _containerColor,
      );

  Color get taskbarBackgroundColor {
    final double opacity = _taskbarOpacity.clamp(0.0, 1.0);
    return _containerColor.withOpacity(opacity);
  }

  Future<void> initialize() async {
    if (_isLoaded) {
      return;
    }
    await reload();
    _isLoaded = true;
  }

  Future<void> reload() async {
    if (_loading) {
      return;
    }
    _loading = true;
    await _settings.initialize();

    _darkModeEnabled = await _settings.getBool(SettingsKeys.darkModeEnabled);
    _enableBlur = await _settings.getBool(SettingsKeys.enableBlur);
    _primaryColor = Color(await _settings.getInt(SettingsKeys.primaryColor));
    _accentColor = Color(await _settings.getInt(SettingsKeys.accentColor));
    _backgroundColor = Color(await _settings.getInt(SettingsKeys.backgroundColor));
    _containerColor = Color(await _settings.getInt(SettingsKeys.containerColor));
    _taskbarOpacity = await _settings.getDouble(SettingsKeys.taskbarOpacity);
    _showSecondsOnClock = await _settings.getBool(SettingsKeys.showSecondsOnClock);
    final String navbarRaw = await _settings.getString(SettingsKeys.navbarPosition);
    _navbarPosition = navbarPositionFromStorage(navbarRaw);

    _loading = false;
    _isLoaded = true;
    notifyListeners();
  }
}

Color _contrastingColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
}

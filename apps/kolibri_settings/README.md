# Kolibri Settings

A standalone settings application for the Hypr Flutter desktop environment.

## Features

### Phase 1 - Appearance Settings (✅ Completed)

- **Theme Configuration**
  - Dark mode toggle
  - Live theme preview
  
- **Color Customization**
  - Primary color (main accent)
  - Accent color (secondary)
  - Background color
  - Container/panel color
  - Interactive color picker with visual preview
  
- **Taskbar Settings**
  - Opacity control (0-100%)
  - Blur effect toggle
  
- **Clock Settings**
  - Show/hide seconds option
  
- **Settings Management**
  - Real-time preview of changes
  - Save/Reset/Restore defaults buttons
  - Persistent storage in `~/.config/hypr_flutter/appearance.json`

### Phase 2 - Display Management (✅ COMPLETED)

- Monitor detection via `hyprctl monitors -j`
- Resolution configuration with auto-updating refresh rates
- Position controls (X, Y coordinates)
- Scale adjustment (0.5x - 3.0x)
- Rotation support (0°, 90°, 180°, 270°)
- Enable/disable monitors (with safety checks)
- Primary display selection
- Refresh rate settings
- Save to JSON and apply to Hyprland

### Phase 3 - Visual Canvas Display Manager (✅ COMPLETED)

- **Interactive canvas with draggable monitors** 🎨
- **Drag-and-drop positioning** - Click and drag to reposition
- Real-time visual preview of monitor arrangement
- Grid background with origin marker
- Zoom controls (5% - 50%) with scroll-to-zoom
- Click to select monitor and view settings
- Primary monitor highlighting
- Monitor info bar at bottom showing all details
- Real-time position field updates during drag
- **Snap-to-grid** - Automatically aligns to 100px grid
- **Snap-to-edges** - Magnetically aligns to other monitors
- **Canvas panning** - Drag background to navigate (constrained)
- **Responsive layout** - Settings below canvas on narrow screens
- Hyprland config generation and application
- **🔒 Safety: Cannot disable primary monitor**
- **🔒 Safety: Cannot disable only enabled monitor**

### NEW: Confirmation Modal & Persistence (✅ COMPLETED)

- **15-second confirmation countdown** ⏱️
  - Modal dialog appears after clicking "Apply"
  - Auto-reverts if not confirmed (prevents broken configs)
  - Manual "Revert Now" button always available
  - Progress bar with color-coded urgency
- **Full persistence support** 💾
  - Saves to `~/.config/hypr_flutter/display.json`
  - Generates executable shell script for Hyprland startup
  - `apply_displays.sh` contains hyprctl commands
  - One-line integration: `exec-once = ~/.config/hypr_flutter/apply_displays.sh`
- **Safety matching Windows/GNOME**
  - Same behavior as major desktop environments
  - Can't get stuck with broken display
  - Previous config always preserved

### Phase 4 - Integration (Planned)

- File watcher integration with main app
- Remove embedded settings from main panel
- Standalone launcher entry
- Auto-reload configurations

## Usage

### Running the App

```bash
cd apps/kolibri_settings
flutter run -d linux
```

### Building

```bash
cd apps/kolibri_settings
flutter build linux
```

The binary will be in `build/linux/x64/release/bundle/kolibri_settings`

### Making Display Settings Persistent

After configuring your displays and clicking "Keep Changes":

1. The app generates: `~/.config/hypr_flutter/apply_displays.sh`
1. Add this line to your `~/.config/hypr/hyprland.conf`:

```conf
exec-once = ~/.config/hypr_flutter/apply_displays.sh
```

1. Your display settings will now apply automatically on every Hyprland startup!

See [DISPLAY_PERSISTENCE.md](DISPLAY_PERSISTENCE.md) for detailed instructions.

## Configuration Files

All configuration files are stored in `~/.config/hypr_flutter/`:

- `appearance.json` - Theme and appearance settings
- `display.json` - Monitor configurations (Phase 2)
- `general.json` - General system settings (Phase 4)

### Example `appearance.json`

```json
{
  "darkMode": true,
  "primaryColor": 4280811237,
  "accentColor": 4294954752,
  "backgroundColor": 4279374354,
  "containerColor": 4279702047,
  "taskbarOpacity": 0.9,
  "enableBlur": true,
  "showSecondsOnClock": false
}
```

## Architecture

### Services

- **ConfigService** - Handles JSON file I/O for all configurations
- Located in `lib/services/config_service.dart`

### Models

- **AppearanceConfig** - Theme and appearance data model
- **DisplayConfig** - Monitor configuration (Phase 2)
- Located in `lib/models/`

### Screens

- **AppearanceScreen** - Theme and color customization
- **DisplayScreen** - Monitor management (Phase 2)
- **GeneralScreen** - System settings (Phase 4)

## Development

### Adding New Settings

1. Add properties to the relevant config model
2. Update `toJson()` and `fromJson()` methods
3. Add UI controls in the corresponding screen
4. Test save/load functionality

### Color Picker Usage

The app uses `flutter_colorpicker` for color selection. Colors are stored as integer values representing ARGB color codes.

```dart
// Example color picker implementation
_showColorPicker(currentColor, (newColor) {
  // Handle color change
  _updateConfig(_config.copyWith(primaryColor: newColor));
});
```

## Dependencies

- `flutter_colorpicker` - Color selection UI
- `shared_preferences` - Key-value storage
- `path` - File path utilities
- `file_picker` - File selection dialogs

## Integration with Main App

The settings app shares the same config directory (`~/.config/hypr_flutter/`) with the main Hypr Flutter panel. Changes made in this app will be available to the main app through:

1. **Direct file reading** - Main app reads config files on startup
2. **File watchers** - Live reload of configurations (Phase 4)

## License

Part of the Hypr Flutter project.

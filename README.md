# Kolibri Shell

> "It's not like we are using React in our start menu..."

- Kolibri Shell [KO - li - bree] 

## Features

### Taskbar

- Icon showing the distro logo
- Active workspaces
  - Shows the application that is currently active on each workspace
- Music player
  - Album cover
  - Background is composed from the album cover
  - Title & artist
  - Progress bar
  - On hover shows buttons like previous, play/pause, next and progress bar controller
  - On click opens the music player
- Active window
  - Icon of the active window
  - Program name & title
  - Indicator to show which display is focused
- Battery indicator
  - Percentage
  - Status
- Clock
  - Date
  - Time (seconds are optional)
- System tray
  - Volume of default sink
  - Wifi / ethernet status
  - Bluetooth status

## Architecture

Kolibri Shell is built with a forked version of the Flutter Linux Window Manager Plugin, which offers the support for multiple windows (with layer shell protocol) in one application.
Original plugin: <https://pub.dev/packages/fl_linux_window_manager>

The forked version offers more features:
- Get monitor list & set monitor [Created by Hanibachi](https://github.com/Hanibachi)
- Is window visible function
- Set focus function
- Is window ID used function

## Installation (WIP)

Use the installer to install Kolibri Shell.
The installer will automatically check your flutter installation, install the necessary packages, clone the repository and build the application.

## Performance

Near native performance
Flutter offers near-native performance.
The small loss in performance is offset by the ease of customization, development & support.

### Comparison -> Waybar vs Quickshell vs Kolibri Shell

| Description  | Waybar | Quickshell | Kolibri Shell |
| --- | --- | --- | --- |
| Performance | Native | Near native | Near native |
| Customizable | Yes | Yes | Yes |
| Features | Restricted | Many | Many |
| GUI toolkit | GTK | Qt | Flutter (GTK) |
| Ease of customization | Easy | Hard | Medium |
| Language for customization | Json & GTK CSS | QML | Dart (Flutter) |
| WM Integration | any Wayland WM | Hyprland & I3 | Hyprland |

//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <battery_plus/battery_plus_windows_plugin.h>
#include <flutter_volume_controller/flutter_volume_controller_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  BatteryPlusWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BatteryPlusWindowsPlugin"));
  FlutterVolumeControllerPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterVolumeControllerPluginCApi"));
}

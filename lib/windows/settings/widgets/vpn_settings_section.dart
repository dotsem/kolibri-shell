import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/utils/settings_helper.dart';
import 'package:hypr_flutter/windows/settings/widgets/settings_section.dart';
import 'package:hypr_flutter/windows/settings/widgets/toggles.dart';

class VpnSettingsSection extends StatefulWidget {
  const VpnSettingsSection({super.key});

  @override
  State<VpnSettingsSection> createState() => _VpnSettingsSectionState();
}

class _VpnSettingsSectionState extends State<VpnSettingsSection> {
  bool _showVpnTab = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      _showVpnTab = await SettingsHelper.get<bool>(SettingsKeys.showVpnTab);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleVpnTab(bool value) async {
    if (_isLoading) return;
    
    setState(() {
      _showVpnTab = value;
    });
    
    await SettingsHelper.set<bool>(SettingsKeys.showVpnTab, value);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'VPN Settings',
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          SettingsSwitchTile(
            title: 'Show VPN Tab',
            value: _showVpnTab,
            onChanged: _toggleVpnTab,
            subtitle: 'Show or hide the VPN tab in the right sidebar',
          ),
      ],
    );
  }
}

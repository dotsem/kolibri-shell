import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/settings.dart';
import 'package:hypr_flutter/utils/settings_helper.dart';
import 'package:path_provider/path_provider.dart';

class VpnConfig {
  final String id;
  final String name;
  final String filePath;
  final String username;
  final String password;
  bool isActive;
  bool isConnected;

  VpnConfig({
    required this.id,
    required this.name,
    required this.filePath,
    this.username = '',
    this.password = '',
    this.isActive = false,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
    'username': username,
    'password': password,
    'isActive': isActive,
    'isConnected': isConnected,
  };

  factory VpnConfig.fromJson(Map<String, dynamic> json) => VpnConfig(
    id: json['id'],
    name: json['name'],
    filePath: json['filePath'],
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    isActive: json['isActive'] ?? false,
    isConnected: json['isConnected'] ?? false,
  );
}

class VpnService extends ChangeNotifier {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;

  List<VpnConfig> _configs = [];
  VpnConfig? _activeConfig;
  Process? _vpnProcess;
  bool _isLoading = false;
  String _status = 'Disconnected';
  String _log = '';

  bool get isLoading => _isLoading;
  String get status => _status;
  String get log => _log;
  List<VpnConfig> get configs => List.unmodifiable(_configs);
  VpnConfig? get activeConfig => _activeConfig;

  VpnService._internal() {
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final configsJson = await SettingsHelper.get<String>(SettingsKeys.vpnConfigs);
      final activeConfigId = await SettingsHelper.get<String>(SettingsKeys.activeVpnConfig);

      if (configsJson.isNotEmpty) {
        final List<dynamic> configsList = json.decode(configsJson);
        _configs = configsList.map((c) => VpnConfig.fromJson(c)).toList();

        if (activeConfigId.isNotEmpty) {
          try {
            _activeConfig = _configs.firstWhere(
              (c) => c.id == activeConfigId,
              orElse: () => _configs.firstWhere((c) => c.isActive),
            );
          } catch (e) {
            _log += 'Error finding active config: $e\n';
          }
        }
      }
    } catch (e) {
      _log += 'Error loading VPN configs: $e\n';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveConfigs() async {
    try {
      final configsJson = json.encode(_configs.map((c) => c.toJson()).toList());
      await SettingsHelper.set<String>(SettingsKeys.vpnConfigs, configsJson);

      if (_activeConfig != null) {
        await SettingsHelper.set<String>(SettingsKeys.activeVpnConfig, _activeConfig!.id);
      }
    } catch (e) {
      _log += 'Error saving VPN configs: $e\n';
      rethrow;
    }
  }

  Future<void> addConfig(VpnConfig config) async {
    _configs.add(config);
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> updateConfig(VpnConfig config) async {
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      _configs[index] = config;
      await _saveConfigs();
      notifyListeners();
    }
  }

  Future<void> removeConfig(String id) async {
    // Clean up the imported openvpn3 config if it exists
    try {
      final configName = 'hypr-vpn-$id';
      final removeResult = await Process.run('openvpn3', ['config-remove', '--config', configName]);
      if (removeResult.exitCode == 0) {
        _log += 'Removed openvpn3 config: $configName\n';
      }
    } catch (e) {
      _log += 'Error removing openvpn3 config: $e\n';
    }

    _configs.removeWhere((c) => c.id == id);
    if (_activeConfig?.id == id) {
      _activeConfig = null;
      await SettingsHelper.set<String>(SettingsKeys.activeVpnConfig, '');
    }
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> setActiveConfig(String id) async {
    _activeConfig = _configs.firstWhere((c) => c.id == id);
    await _saveConfigs();
    notifyListeners();
  }

  Future<bool> connect() async {
    if (_activeConfig == null) {
      _log += 'No active VPN configuration selected\n';
      return false;
    }

    _status = 'Connecting...';
    notifyListeners();

    try {
      final config = _activeConfig!;
      final configName = 'hypr-vpn-${config.id}';

      // Check if the config already exists in openvpn3
      final listResult = await Process.run('openvpn3', ['configs-list']);
      final configExists = listResult.stdout.toString().contains(configName);

      // Only import if it doesn't exist
      if (!configExists) {
        final importResult = await Process.run('openvpn3', [
          'config-import',
          '--config',
          config.filePath,
          '--name',
          configName,
          '--persistent',
        ]);

        if (importResult.exitCode != 0) {
          _log += 'Failed to import VPN config: ${importResult.stderr}\n';
          _status = 'Error';
          notifyListeners();
          return false;
        }
        _log += 'VPN config imported successfully\n';
      } else {
        _log += 'Using existing VPN config\n';
      }

      // Start the VPN connection
      final args = ['session-start', '--config', configName, '--timeout', '20'];

      _vpnProcess = await Process.start('openvpn3', args);

      // If we have credentials, provide them when prompted
      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        _vpnProcess!.stdin.writeln(config.username);
        _vpnProcess!.stdin.writeln(config.password);
        await _vpnProcess!.stdin.flush();
      }

      _vpnProcess!.stdout.listen((data) {
        _log += String.fromCharCodes(data);
        notifyListeners();
      });

      _vpnProcess!.stderr.listen((data) {
        _log += String.fromCharCodes(data);
        notifyListeners();
      });

      _vpnProcess!.exitCode.then((code) async {
        _isLoading = false;
        _status = code == 0 ? 'Connected' : 'Disconnected';
        if (code != 0) {
          _log += 'VPN process exited with code $code\n';
        }
        notifyListeners();
      });

      _status = 'Connected';
      _activeConfig!.isConnected = true;
      _activeConfig!.isActive = true;
      await _saveConfigs();
      return true;
    } catch (e) {
      _isLoading = false;
      _status = 'Error';
      _log += 'Error connecting to VPN: $e\n';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_activeConfig != null) {
      final configName = 'hypr-vpn-${_activeConfig!.id}';

      // Try to gracefully disconnect using openvpn3
      try {
        final disconnectResult = await Process.run('openvpn3', [
          'session-manage',
          '--disconnect',
          '--config',
          configName,
        ]);
        if (disconnectResult.exitCode == 0) {
          _log += 'VPN session disconnected\n';
        } else {
          _log += 'Disconnect result: ${disconnectResult.stderr}\n';
        }
      } catch (e) {
        _log += 'Error during graceful disconnect: $e\n';
      }

      // Force kill if still running
      if (_vpnProcess != null) {
        _vpnProcess!.kill();
        _vpnProcess = null;
      }

      // Note: We don't remove the imported config here anymore
      // This allows it to persist for the next connection
      // If you want to remove it, the user can delete the VPN configuration entirely

      _activeConfig!.isConnected = false;
      _activeConfig!.isActive = false;
      await _saveConfigs();
    }

    _status = 'Disconnected';
    notifyListeners();
  }
}

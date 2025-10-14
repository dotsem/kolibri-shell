import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/services/vpn_service.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

class VpnTab extends StatefulWidget {
  const VpnTab({super.key});

  @override
  State<VpnTab> createState() => _VpnTabState();
}

class _VpnTabState extends State<VpnTab> {
  final VpnService _vpnService = VpnService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _configPath;
  bool _isAddingConfig = false;
  bool _isConnecting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickConfigFile() async {
    try {
      // Get the user's home directory
      final homeDir = getHomeDirectory();
      final downloadsDir = path.join(homeDir, 'Downloads');
      
      // Use zenity for file selection
      final result = await Process.run('zenity', [
        '--file-selection',
        '--title=Select OpenVPN Configuration',
        '--filename=$downloadsDir/',
        '--file-filter=OpenVPN Config (*.ovpn *.OVPN) | *.ovpn *.OVPN',
        '--file-filter=All files | *',
      ]);
      
      if (result.exitCode != 0) {
        // User clicked cancel or dialog was closed
        return;
      }
      
      final filePath = result.stdout.toString().trim();
      if (filePath.isEmpty) return;
      
      // Verify the file has a .ovpn extension (case insensitive)
      if (!filePath.toLowerCase().endsWith('.ovpn')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a .ovpn configuration file')),
          );
        }
        return;
      }
      
      // Verify the file exists
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected file does not exist')),
          );
        }
        return;
      }
      
      // Update the UI with the selected file
      if (mounted) {
        setState(() {
          _configPath = filePath;
          if (_nameController.text.isEmpty) {
            final fileName = path.basename(filePath);
            _nameController.text = fileName.replaceAll(RegExp(r'\.ovpn$', caseSensitive: false), '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  String getHomeDirectory() {
    // Try to get the home directory from environment variables
    final envVars = Platform.environment;
    if (envVars.containsKey('HOME')) {
      return envVars['HOME']!;
    }
    
    // Fallback to the current working directory
    return Directory.current.path;
  }

  Future<void> _saveConfig() async {
    if (_configPath == null || _nameController.text.isEmpty) return;

    final config = VpnConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      filePath: _configPath!,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    await _vpnService.addConfig(config);
    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _configPath = null;
      _isAddingConfig = false;
    });
  }

  Widget _buildConfigForm() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Connection Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_configPath ?? 'No file selected',
                      overflow: TextOverflow.ellipsis),
                ),
                TextButton(
                  onPressed: _pickConfigFile,
                  child: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isAddingConfig = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveConfig,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(VpnConfig config) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          config.isConnected ? Icons.vpn_lock : Icons.vpn_key,
          color: config.isConnected ? Colors.green : null,
        ),
        title: Text(config.name),
        subtitle: Text(config.filePath.split('/').last),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.isConnected)
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.red),
                onPressed: _isConnecting ? null : () => _disconnectVpn(),
              )
            else
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                onPressed: _isConnecting ? null : () => _connectVpn(config),
              ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              onSelected: (value) async {
                if (value == 'delete') {
                  await _vpnService.removeConfig(config.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectVpn(VpnConfig config) async {
    setState(() => _isConnecting = true);
    await _vpnService.setActiveConfig(config.id);
    await _vpnService.connect();
    setState(() => _isConnecting = false);
  }

  Future<void> _disconnectVpn() async {
    setState(() => _isConnecting = true);
    await _vpnService.disconnect();
    setState(() => _isConnecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vpnService,
      child: Consumer<VpnService>(
        builder: (context, vpnService, _) {
          return Column(
            children: [
              if (_isAddingConfig) _buildConfigForm(),
              if (!_isAddingConfig)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VPN Connections',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _isAddingConfig = true),
                        tooltip: 'Add VPN Configuration',
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: vpnService.isLoading && vpnService.configs.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : vpnService.configs.isEmpty
                        ? const Center(child: Text('No VPN configurations found'))
                        : ListView.builder(
                            itemCount: vpnService.configs.length,
                            itemBuilder: (context, index) {
                              final config = vpnService.configs[index];
                              return _buildConfigItem(config);
                            },
                          ),
              ),
              if (vpnService.log.isNotEmpty)
                Container(
                  height: 150,
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      vpnService.log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

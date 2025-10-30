import 'dart:io';
import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/panels/menu/widgets/menu_search_bar.dart';
import 'package:hypr_flutter/panels/menu/widgets/selectable_card.dart';
import 'package:hypr_flutter/window_ids.dart';

class PowerMenu extends StatefulWidget {
  const PowerMenu({super.key});

  @override
  State<PowerMenu> createState() => _PowerMenuState();
}

class _PowerMenuState extends State<PowerMenu> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_PowerOption> _allOptions = [
    _PowerOption(
      icon: Icons.lock,
      label: 'Lock',
      command: 'hyprlock',
      needsConfirmation: false,
      searchTerms: ['lock', 'screen', 'coffee'],
    ),
    _PowerOption(
      icon: Icons.logout,
      label: 'Logout',
      command: 'hyprctl dispatch exit',
      needsConfirmation: false,
      searchTerms: ['logout', 'exit', 'sign out'],
    ),
    _PowerOption(
      icon: Icons.bedtime,
      label: 'Sleep',
      command: 'systemctl suspend',
      needsConfirmation: false,
      searchTerms: ['sleep', 'suspend'],
    ),
    _PowerOption(
      icon: Icons.nights_stay,
      label: 'Hibernate',
      command: 'systemctl hibernate',
      needsConfirmation: false,
      searchTerms: ['hibernate'],
    ),
    _PowerOption(
      icon: Icons.restart_alt,
      label: 'Restart',
      command: 'systemctl reboot',
      needsConfirmation: true,
      color: Colors.orange,
      searchTerms: ['restart', 'reboot'],
    ),
    _PowerOption(
      icon: Icons.power_settings_new,
      label: 'Shutdown',
      command: 'systemctl poweroff',
      needsConfirmation: true,
      color: Colors.red,
      searchTerms: ['shutdown', 'power off', 'turn off', 'nuke'],
    ),
  ];

  List<_PowerOption> _filteredOptions = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredOptions = _allOptions;
    _searchController.addListener(_filterOptions);

    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Request focus whenever dependencies change (when widget becomes visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = _allOptions;
      } else {
        _filteredOptions = _allOptions.where((option) {
          return option.label.toLowerCase().contains(query) ||
              option.searchTerms.any((term) => term.contains(query));
        }).toList();
      }
      // Reset selection when filter changes
      _selectedIndex = _filteredOptions.isEmpty
          ? 0
          : _selectedIndex.clamp(0, _filteredOptions.length - 1);
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_filteredOptions.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _filteredOptions.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1) % _filteredOptions.length;
        if (_selectedIndex < 0) _selectedIndex = _filteredOptions.length - 1;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _executeOption(_filteredOptions[_selectedIndex]);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final itemHeight = 80.0; // Approximate height of card + spacing
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = _selectedIndex * itemHeight;

      if (targetOffset < _scrollController.offset) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else if (targetOffset + itemHeight > _scrollController.offset + viewportHeight) {
        _scrollController.animateTo(
          targetOffset + itemHeight - viewportHeight,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _executeOption(_PowerOption option) {
    if (option.needsConfirmation) {
      _showConfirmDialog(
        option.label,
        'Are you sure you want to ${option.label.toLowerCase()}?',
        () => _executeCommand(option.command),
      );
    } else {
      _executeCommand(option.command);
    }
  }

  Future<void> _executeCommand(String command) async {
    // Hide the menu first
    await FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);

    // Execute the command
    try {
      await Process.run('sh', ['-c', command]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep search bar focused after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
    });

    return Focus(
      autofocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final key = event.logicalKey;

        // Handle navigation keys
        if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.escape) {
          _handleKeyEvent(event);
          // Keep TextField focused after navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_searchFocusNode.hasFocus) {
              _searchFocusNode.requestFocus();
            }
          });
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Power Options',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Search bar
            MenuSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search power options...',
              onClear: () {
                setState(() {
                  _filteredOptions = _allOptions;
                  _selectedIndex = 0;
                });
              },
            ),
            const SizedBox(height: 16),

            // Power options
            Expanded(
              child: _filteredOptions.isEmpty
                  ? Center(
                      child: Text(
                        'No results found',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: _filteredOptions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        final isSelected = index == _selectedIndex;

                        return SelectableCard(
                          leading: Icon(
                            option.icon,
                            color: option.color ?? Theme.of(context).colorScheme.primary,
                            size: 40,
                          ),
                          title: option.label,
                          isSelected: isSelected,
                          onHover: () {
                            if (_selectedIndex != index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            }
                          },
                          onTap: () => _executeOption(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerOption {
  final IconData icon;
  final String label;
  final String command;
  final bool needsConfirmation;
  final Color? color;
  final List<String> searchTerms;

  _PowerOption({
    required this.icon,
    required this.label,
    required this.command,
    required this.needsConfirmation,
    this.color,
    required this.searchTerms,
  });
}

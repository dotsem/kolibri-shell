import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/services/app_launcher_service.dart';
import 'package:hypr_flutter/services/window_icon_resolver.dart';
import 'package:hypr_flutter/window_ids.dart';

class AppLauncher extends StatefulWidget {
  final void Function(KeyEvent)? onKeyEvent;

  const AppLauncher({super.key, this.onKeyEvent});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  final AppLauncherService _launcherService = AppLauncherService();
  final WindowIconResolver _iconResolver = WindowIconResolver.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _launcherService.addListener(_onServiceUpdate);
    _resetState();
  }

  @override
  void didUpdateWidget(AppLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetState();
  }

  void _resetState() {
    // Reset all state when menu is opened
    setState(() {
      _selectedIndex = 0;
      _searchController.clear();
      _launcherService.clearSearch();
    });

    // Auto-focus search field when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _launcherService.removeListener(_onServiceUpdate);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {
        // Reset selection when apps list changes, but keep it in bounds
        final apps = _launcherService.apps;
        if (apps.isEmpty) {
          _selectedIndex = 0;
        } else {
          _selectedIndex = _selectedIndex.clamp(0, apps.length - 1);
        }
      });
    }
  }

  Future<void> _initializeService() async {
    if (!_launcherService.isInitialized) {
      await _launcherService.initialize();
    }
  }

  void _onSearchChanged(String query) {
    _launcherService.search(query);
    setState(() {
      _selectedIndex = 0; // Reset selection when search changes
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    // Pass to parent if callback is provided
    widget.onKeyEvent?.call(event);

    // Handle Escape key to close menu
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
      return;
    }

    final apps = _launcherService.apps;
    if (apps.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_selectedIndex < apps.length - 1) {
          _selectedIndex++;
          _scrollToSelected();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_selectedIndex > 0) {
          _selectedIndex--;
          _scrollToSelected();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedIndex >= 0 && _selectedIndex < apps.length) {
        _onAppTap(apps[_selectedIndex]);
      }
    }
  }

  void _scrollToSelected() {
    // Check if scroll controller is attached and has clients
    if (!_scrollController.hasClients) return;

    // Calculate item position and scroll to it
    const itemHeight = 72.0; // Approximate height of ListTile
    final targetOffset = _selectedIndex * itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    // Scroll if selected item is not fully visible
    if (targetOffset < currentOffset) {
      _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _scrollController.animateTo(targetOffset + itemHeight - viewportHeight, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _onAppTap(LaunchableApp app) async {
    final success = await _launcherService.launch(app);
    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to launch ${app.app.name}'), duration: const Duration(seconds: 2)));
      } else {
        FlLinuxWindowManager.instance.hideWindow(windowId: WindowIds.menu);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        // Only handle navigation keys and Enter/Escape
        // Let everything else pass through to TextField
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.escape) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search applications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _launcherService.clearSearch();
                            _selectedIndex = 0; // Reset selection when clearing search
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ),

          // App list
          Expanded(child: _buildAppList(theme)),
        ],
      ),
    );
  }

  Widget _buildAppList(ThemeData theme) {
    if (_launcherService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final apps = _launcherService.apps;

    if (apps.isEmpty) {
      return Center(
        child: Text(_launcherService.searchQuery.isEmpty ? 'No applications found' : 'No results for "${_launcherService.searchQuery}"', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = index == _selectedIndex;
        return _buildAppTile(app, theme, isSelected);
      },
    );
  }

  Widget _buildAppTile(LaunchableApp app, ThemeData theme, bool isSelected) {
    return ListTile(
      leading: _iconResolver.buildIcon(app.iconData, size: 40, borderRadius: 8, fallbackIcon: Icons.apps),
      title: Text(app.app.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: app.app.comment != null
          ? Text(
              app.app.comment!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            )
          : null,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      onTap: () {
        // Update selection index when clicking
        final apps = _launcherService.apps;
        final index = apps.indexOf(app);
        if (index != -1) {
          setState(() {
            _selectedIndex = index;
          });
        }
        _onAppTap(app);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

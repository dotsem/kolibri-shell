import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/services/app_launcher_service.dart';
import 'package:hypr_flutter/services/favorite_apps_service.dart';
import 'package:hypr_flutter/services/hidden_apps_service.dart';
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
  final HiddenAppsService _hiddenAppsService = HiddenAppsService();
  final FavoriteAppsService _favoriteAppsService = FavoriteAppsService();
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
      autofocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }

        final key = event.logicalKey;

        // Always handle Escape to close menu
        if (key == LogicalKeyboardKey.escape) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        }

        // Handle navigation keys (arrows and Enter) only if they're not being used in TextField
        // This allows arrow keys to navigate the list while typing still works in TextField
        if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
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
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                // Master eye toggle
                IconButton(
                  icon: Icon(_hiddenAppsService.showHiddenApps ? Icons.visibility : Icons.visibility_off, color: _hiddenAppsService.hiddenCount > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
                  tooltip: _hiddenAppsService.showHiddenApps ? 'Hide hidden apps' : 'Show hidden apps (${_hiddenAppsService.hiddenCount})',
                  onPressed: () {
                    setState(() {
                      _hiddenAppsService.toggleShowHidden();
                    });
                  },
                ),
              ],
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
    final isHidden = _hiddenAppsService.isHidden(app.app.id);
    final isFavorite = _favoriteAppsService.isFavorite(app.app.id);

    return ListTile(
      leading: _iconResolver.buildIcon(app.iconData, size: 40, borderRadius: 8, fallbackIcon: Icons.apps),
      title: Row(
        children: [
          Expanded(
            child: Text(app.app.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          ),
          // Favorite star icon
          IconButton(
            icon: Icon(isFavorite ? Icons.star : Icons.star_border, size: 20, color: isFavorite ? Colors.amber : theme.colorScheme.onSurface.withOpacity(0.6)),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () {
              setState(() {
                _favoriteAppsService.toggleAppFavorite(app.app.id);
              });
            },
          ),
        ],
      ),
      subtitle: app.app.comment != null
          ? Text(
              app.app.comment!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            )
          : null,
      trailing: IconButton(
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility, size: 20),
        tooltip: isHidden ? 'Show this app' : 'Hide this app',
        onPressed: () {
          setState(() {
            _hiddenAppsService.toggleAppHidden(app.app.id);
          });
        },
      ),
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

import 'package:fl_linux_window_manager/fl_linux_window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hypr_flutter/panels/menu/widgets/menu_search_bar.dart';
import 'package:hypr_flutter/panels/menu/widgets/selectable_card.dart';
import 'package:hypr_flutter/services/menu_service.dart';
import 'package:hypr_flutter/window_ids.dart';

class GlobalMenu extends StatefulWidget {
  const GlobalMenu({super.key});

  @override
  State<GlobalMenu> createState() => _GlobalMenuState();
}

class _GlobalMenuState extends State<GlobalMenu> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_MenuItem> _allMenuItems = [
    _MenuItem(
      icon: Icons.apps,
      title: 'Applications',
      subtitle: 'Browse and launch apps',
      menuType: MenuType.apps,
      searchTerms: ['apps', 'applications', 'launcher', 'programs'],
    ),
    _MenuItem(
      icon: Icons.power_settings_new,
      title: 'Power',
      subtitle: 'Lock, logout, shutdown',
      menuType: MenuType.power,
      searchTerms: ['power', 'shutdown', 'restart', 'lock', 'logout', 'sleep', 'hibernate'],
    ),
  ];

  List<_MenuItem> _filteredItems = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredItems = _allMenuItems;
    _searchController.addListener(_filterItems);

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

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allMenuItems;
      } else {
        _filteredItems = _allMenuItems.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.subtitle.toLowerCase().contains(query) ||
              item.searchTerms.any((term) => term.contains(query));
        }).toList();
      }
      // Reset selection when filter changes
      _selectedIndex = _filteredItems.isEmpty
          ? 0
          : _selectedIndex.clamp(0, _filteredItems.length - 1);
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_filteredItems.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _filteredItems.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1) % _filteredItems.length;
        if (_selectedIndex < 0) _selectedIndex = _filteredItems.length - 1;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _selectItem(_filteredItems[_selectedIndex]);
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

  void _selectItem(_MenuItem item) {
    MenuService().navigateTo(item.menuType);
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
              'Menu',
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
              hintText: 'Search menu...',
              onClear: () {
                setState(() {
                  _filteredItems = _allMenuItems;
                  _selectedIndex = 0;
                });
              },
            ),
            const SizedBox(height: 16),

            // Menu items
            Expanded(
              child: _filteredItems.isEmpty
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
                      itemCount: _filteredItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = index == _selectedIndex;

                        return SelectableCard(
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          title: item.title,
                          subtitle: item.subtitle,
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          isSelected: isSelected,
                          onHover: () {
                            if (_selectedIndex != index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            }
                          },
                          onTap: () => _selectItem(item),
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

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final MenuType menuType;
  final List<String> searchTerms;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.menuType,
    required this.searchTerms,
  });
}

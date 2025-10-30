import 'package:flutter/material.dart';

class MenuSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const MenuSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                controller.clear();
                onClear?.call();
              },
            ),
        ],
      ),
    );
  }
}

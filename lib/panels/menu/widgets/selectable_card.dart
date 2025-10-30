import 'package:flutter/material.dart';

/// A reusable card widget that can be selected with keyboard navigation
class SelectableCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isSelected;
  final VoidCallback? onHover;

  const SelectableCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.isSelected = false,
    this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onHover: (hovering) {
          if (hovering) {
            onHover?.call();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

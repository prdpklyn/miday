import 'package:flutter/material.dart';
import 'package:my_day/core/theme/app_theme.dart';

class AdaptiveSection extends StatelessWidget {
  final String title;
  final int itemCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing; // Optional badge or count
  final int maxCollapsedItems;

  const AdaptiveSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.trailing,
    this.maxCollapsedItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with tap to expand/collapse
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTheme.sectionHeader),
                    const SizedBox(width: 8),
                    // Expand/collapse icon
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        
        // Content with animation
        AnimatedCrossFade(
          firstChild: child,
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded 
              ? CrossFadeState.showFirst 
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/search'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: context.colors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search housing, areas, or roommates…',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.outline,
                ),
              ),
            ),
            Icon(Icons.tune, color: context.colors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

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
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: AppColors.primary, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search housing, areas, or roommates…',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.outline,
                ),
              ),
            ),
            Icon(Icons.tune, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

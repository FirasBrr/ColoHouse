import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        QuickAction(
            icon: Icons.home_outlined,
            label: 'Browse',
            onTap: () => context.go('/search'), // Navigate to the search tab
          ),
        const SizedBox(width: 10),
        QuickAction(
          icon: Icons.group_outlined,
          label: 'Roommates',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Matching coming soon')),
          ),
        ),
        const SizedBox(width: 10),
        QuickAction(
          icon: Icons.add_circle_outline,
          label: 'Post',
          onTap: () => context.go('/post'),
        ),
        const SizedBox(width: 10),
        QuickAction(
          icon: Icons.tune,
          label: 'Preferences',
          onTap: () => context.push('/profile/preferences'),
        ),
      ],
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

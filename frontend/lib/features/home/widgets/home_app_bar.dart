import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add this
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart'; // Add this

class HomeAppBar extends ConsumerWidget { // Change to ConsumerWidget
  final dynamic user;

  const HomeAppBar({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Add WidgetRef
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceLowest,
        border: Border(
          bottom: BorderSide(
            color: context.colors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.primary,
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Colohouse',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          
          // --- DARK MODE TOGGLE BUTTON ---
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: context.colors.onSurfaceVariant,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),

          // Notification Bell
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: context.colors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}
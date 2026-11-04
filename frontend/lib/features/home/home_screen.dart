import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/placeholder_card.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/section_header.dart';
import 'widgets/verification_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          HomeAppBar(user: user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Greeting
                Text(
                  _greeting(user?.firstName),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Here's what's happening near you",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 20),

                // Search bar (visual, non-functional for now)
                const HomeSearchBar(),
                const SizedBox(height: 16),

                // Verification banner (only if not verified)
                if (user != null && !user.isVerified) ...[
                  VerificationBanner(
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const SizedBox(height: 20),
                ],

                // Quick actions
                const QuickActionsRow(),
                const SizedBox(height: 24),

                // Recommended for you — placeholder
                SectionHeader(
                  title: 'Recommended for you',
                  onSeeAll: () => _showComingSoon(context, 'Listings'),
                ),
                const SizedBox(height: 12),
                const PlaceholderCard(
                  icon: Icons.home_work_outlined,
                  title: 'Housing listings',
                  subtitle:
                      'Browse, filter, and save listings from other members. ',
                  height: 180,
                ),
                const SizedBox(height: 24),

                // Potential roommates — placeholder
                SectionHeader(
                  title: 'Potential roommates',
                  onSeeAll: () => _showComingSoon(context, 'Matching'),
                ),
                const SizedBox(height: 12),
                const PlaceholderCard(
                  icon: Icons.groups_outlined,
                  title: 'Roommate matching ',
                  subtitle:
                      'We\'ll suggest compatible people based on your preferences.',
                  height: 180,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return name == null || name.isEmpty
        ? '$greeting 👋'
        : '$greeting, $name 👋';
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _HomeAppBar(user: user),
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
                _SearchBar(),
                const SizedBox(height: 16),

                // Verification banner (only if not verified)
                if (user != null && !user.isVerified) ...[
                  _VerificationBanner(
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const SizedBox(height: 20),
                ],

                // Quick actions
                _QuickActionsRow(),
                const SizedBox(height: 24),

                // Recommended for you — placeholder
                _SectionHeader(
                  title: 'Recommended for you',
                  onSeeAll: () => _showComingSoon(context, 'Listings'),
                ),
                const SizedBox(height: 12),
                _PlaceholderCard(
                  icon: Icons.home_work_outlined,
                  title: 'Housing listings',
                  subtitle:
                      'Browse, filter, and save listings from other members. ',
                  height: 180,
                ),
                const SizedBox(height: 24),

                // Potential roommates — placeholder
                _SectionHeader(
                  title: 'Potential roommates',
                  onSeeAll: () => _showComingSoon(context, 'Matching'),
                ),
                const SizedBox(height: 12),
                _PlaceholderCard(
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

// ---------- App bar ----------
class _HomeAppBar extends StatelessWidget {
  final dynamic user;
  const _HomeAppBar({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Colohouse',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.onSurfaceVariant),
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

// ---------- Search bar ----------
class _SearchBar extends StatelessWidget {
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

// ---------- Verification banner ----------
class _VerificationBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _VerificationBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.tertiaryFixed,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline,
                size: 17, color: AppColors.tertiary),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Complete your profile to get verified and unlock all features.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              'Fix →',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Quick actions ----------
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickAction(
          icon: Icons.home_outlined,
          label: 'Browse',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listings coming soon')),
          ),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.group_outlined,
          label: 'Roommates',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Matching coming soon')),
          ),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.add_circle_outline,
          label: 'Post',
          onTap: () => context.go('/post'),
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.tune,
          label: 'Preferences',
          onTap: () => context.push('/profile/preferences'),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
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

// ---------- Section header ----------
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
            ),
            child: const Text(
              'See all →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------- Placeholder card ----------
class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double height;

  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.outline,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
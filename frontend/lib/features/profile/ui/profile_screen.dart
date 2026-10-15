import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_outlined, color: AppColors.primary),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await ref.read(authProvider.notifier).refreshUser();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ===== Header =====
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondaryContainer
                                .withValues(alpha: 0.4),
                            border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.25),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: user.profilePicture != null &&
                                    user.profilePicture!.isNotEmpty
                                ? Image.network(
                                    user.profilePicture!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarFallback(),
                                  )
                                : _avatarFallback(),
                          ),
                        ),
                        if (user.isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(
                                    color: AppColors.surface, width: 2),
                              ),
                              child: const Icon(Icons.check,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName.isEmpty ? 'Your name' : user.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.outline),
                    ),
                    const SizedBox(height: 10),
                    user.isVerified
                        ? _VerifiedPill()
                        : _UnverifiedPill(
                            onTap: () => context.push('/profile/edit'),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ===== Personal Info =====
              _SectionCard(
                title: 'Personal Info',
                icon: Icons.badge_outlined,
                rows: [
                  _InfoRow('Phone', user.phone),
                  _InfoRow('Bio', user.bio),
                ],
              ),
              const SizedBox(height: 16),

              // ===== Background =====
              _SectionCard(
                title: 'Background',
                icon: Icons.school_outlined,
                rows: [
                  _InfoRow('Institution', user.institution),
                  _InfoRow('Occupation', user.occupation),
                  _InfoRow('City', user.city?.name ?? ''),
                ],
              ),
              const SizedBox(height: 24),

              // ===== Actions =====
              _ActionButton(
                icon: Icons.tune,
                label: 'Roommate Preferences',
                onTap: () => context.push('/profile/preferences'),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.settings_outlined,
                label: 'Settings & Privacy',
                onTap: () => context.push('/profile/settings'),
              ),
              const SizedBox(height: 24),

              // ===== Logout (also in AppBar, but here for large tap target) =====
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_outlined, size: 18),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Colohouse — Find Your Home',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return const Center(
      child: Icon(Icons.person, size: 48, color: AppColors.outline),
    );
  }
}

// ---------- Verification pills ----------
class _VerifiedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: AppColors.primaryDark),
          SizedBox(width: 6),
          Text(
            'Verified Account',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnverifiedPill extends StatelessWidget {
  final VoidCallback onTap;
  const _UnverifiedPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.tertiaryFixed.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: AppColors.tertiary),
            SizedBox(width: 6),
            Text(
              'Not verified — complete your profile',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.tertiary,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppColors.tertiary),
          ],
        ),
      ),
    );
  }
}

// ---------- Section card ----------
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Not set' : value;
    final isEmpty = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                color: isEmpty ? AppColors.outline : AppColors.onSurface,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Action row button ----------
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
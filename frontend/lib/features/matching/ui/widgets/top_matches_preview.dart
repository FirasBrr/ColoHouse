import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/matching_providers.dart';
import 'match_card.dart';
import 'matches_list.dart';

/// Home section: the 3 best matches, or a compact empty / error card.
class TopMatchesPreview extends ConsumerWidget {
  const TopMatchesPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    const spinner = SizedBox(
      key: ValueKey('loading'),
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );

    final Widget content = matchesAsync.when(
      loading: () => spinner,
      error: (e, _) => matchesAsync.isLoading
          ? spinner
          : _CompactNotice(
              key: const ValueKey('error'),
              icon: Icons.cloud_off_outlined,
              isError: true,
              title: "Couldn't load roommates",
              subtitle: matchingErrorText(e),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(matchesProvider),
            ),
      data: (matches) {
        if (matches.isEmpty) {
          return _CompactNotice(
            key: const ValueKey('empty'),
            icon: Icons.groups_outlined,
            title: 'No matches yet',
            subtitle: 'Fill in your lifestyle preferences to meet compatible roommates.',
            actionLabel: 'Set up',
            onAction: () => openMatchingPreferences(context, ref),
          );
        }
        return Column(
          key: const ValueKey('data'),
          children: [
            for (final match in matches.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MatchCard(
                  match: match,
                  compact: true,
                  onTap: () => context.push('/roommates/${match.user.id}'),
                ),
              ),
          ],
        );
      },
    );

    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: content);
  }
}

class _CompactNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isError;

  const _CompactNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isError ? context.colors.errorContainer : context.colors.surfaceLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: isError ? context.colors.error : context.colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.35, color: context.colors.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: context.colors.primary),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

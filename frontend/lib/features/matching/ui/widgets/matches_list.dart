import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/auth_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/matching_providers.dart';
import 'match_card.dart';
import 'matching_state_view.dart';

/// Opens the lifestyle preferences, then reloads the matches.
Future<void> openMatchingPreferences(BuildContext context, WidgetRef ref) async {
  // Inside the tabs we push, like the Home quick action. A full-screen page (outside the tabs)
  // can't push a tab route without building the tabs twice (duplicate keys), so it switches tab.
  if (StatefulNavigationShell.maybeOf(context) == null) {
    context.go('/profile/preferences');
    return;
  }
  await context.push('/profile/preferences');
  if (context.mounted) ref.invalidate(matchesProvider);
}

String matchingErrorText(Object error) =>
    error is AuthException ? error.message : 'Something went wrong. Try again.';

/// Ranked compatible roommates with pull-to-refresh (Roommates screen and Search tab).
class MatchesList extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const MatchesList({super.key, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24)});

  // A failed refresh is shown by the error state, not thrown into the RefreshIndicator
  Future<void> _refresh(WidgetRef ref) =>
      ref.refresh(matchesProvider.future).then<void>((_) {}, onError: (_) {});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    final Widget content = matchesAsync.when(
      loading: () => const Center(key: ValueKey('loading'), child: CircularProgressIndicator()),
      error: (e, _) {
        // Retry after an error: show the spinner instead of the old error
        if (matchesAsync.isLoading) {
          return const Center(key: ValueKey('loading'), child: CircularProgressIndicator());
        }
        return _scrollable(
          context,
          ref,
          key: const ValueKey('error'),
          child: MatchingStateView(
            icon: Icons.cloud_off_outlined,
            isError: true,
            title: "Couldn't load roommates",
            message: matchingErrorText(e),
            actions: [
              FilledButton.icon(
                style: MatchingStateView.buttonStyle,
                onPressed: () => ref.invalidate(matchesProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (matches) {
        if (matches.isEmpty) {
          return _scrollable(
            context,
            ref,
            key: const ValueKey('empty'),
            child: MatchingStateView(
              icon: Icons.group_outlined,
              title: 'No compatible roommates yet',
              message: "Fill in your lifestyle preferences and turn on 'Looking for a room' so others can find you too.",
              actions: [
                FilledButton.icon(
                  style: MatchingStateView.buttonStyle,
                  onPressed: () => openMatchingPreferences(context, ref),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Set my preferences'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          key: const ValueKey('data'),
          color: context.colors.primary,
          onRefresh: () => _refresh(ref),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            itemCount: matches.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _ListHeader(count: matches.length);
              final match = matches[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MatchCard(
                  match: match,
                  onTap: () => context.push('/roommates/${match.user.id}'),
                ),
              );
            },
          ),
        );
      },
    );

    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: content);
  }

  // Empty / error states stay pullable, e.g. after editing the preferences
  Widget _scrollable(BuildContext context, WidgetRef ref, {required Key key, required Widget child}) {
    return RefreshIndicator(
      key: key,
      color: context.colors.primary,
      onRefresh: () => _refresh(ref),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// "3 compatible roommates · best first" + shortcut to the preferences.
class _ListHeader extends ConsumerWidget {
  final int count;
  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count compatible ${count == 1 ? 'roommate' : 'roommates'} · best first',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant),
            ),
          ),
          TextButton.icon(
            onPressed: () => openMatchingPreferences(context, ref),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: context.colors.primary),
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Preferences', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

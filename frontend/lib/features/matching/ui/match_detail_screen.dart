import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/match_result.dart';
import '../providers/matching_providers.dart';
import 'widgets/breakdown_bar.dart';
import 'widgets/match_avatar.dart';
import 'widgets/matches_list.dart';
import 'widgets/matching_state_view.dart';
import 'widgets/score_ring.dart';

/// Failed hard filters in words
const _reasonTexts = {
  'smoking': "Your smoking habits don't match",
  'budget': 'Your budgets are more than 30 % apart',
  'move_in_date': 'Your move-in dates are more than 60 days apart',
  'not_looking': "They aren't looking for a room right now",
};

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

/// Compatibility with one person (/roommates/:userId).
class MatchDetailScreen extends ConsumerWidget {
  final int userId;
  const MatchDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _goBack(context)),
        title: const Text('Compatibility'),
      ),
      // The provider caches the future per user; Retry invalidates it and FutureBuilder gets the new one
      body: FutureBuilder<MatchResult>(
        future: ref.watch(matchDetailProvider(userId).future),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                child: MatchingStateView(
                  icon: Icons.person_off_outlined,
                  title: "This profile isn't available",
                  message: 'Only people looking for a room, or who share a housing request with you, can be viewed.',
                  detail: matchingErrorText(snapshot.error!),
                  actions: [
                    FilledButton.icon(
                      style: MatchingStateView.buttonStyle,
                      onPressed: () => _goBack(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Go back'),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(matchDetailProvider(userId)),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.primary,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }
          return _MatchDetailBody(match: snapshot.data!);
        },
      ),
    );
  }
}

class _MatchDetailBody extends StatelessWidget {
  final MatchResult match;
  const _MatchDetailBody({required this.match});

  @override
  Widget build(BuildContext context) {
    final user = match.user;
    final city = match.city ?? '';
    final work = [user.occupation, user.institution].where((s) => s.trim().isNotEmpty).join(' · ');
    final scoreColor = ScoreRing.colorFor(context, match.score);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Header: who + score
        _SectionCard(
          child: Column(
            children: [
              MatchAvatar(user: user, radius: 44),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      user.fullName.isEmpty ? 'ColoHouse member' : user.fullName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.onSurface),
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, size: 20, color: context.colors.primary),
                  ],
                ],
              ),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoLine(icon: Icons.location_on_outlined, text: city),
              ],
              if (work.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoLine(icon: Icons.school_outlined, text: work),
              ],
              const SizedBox(height: 20),
              ScoreRing(score: match.score, size: 132, strokeWidth: 12, showCaption: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  ScoreRing.labelFor(match.score),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor),
                ),
              ),
            ],
          ),
        ),

        if (!match.compatible) ...[
          const SizedBox(height: 16),
          _IncompatibleCard(reasons: match.reasons),
        ],

        if (match.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_outlined, color: context.colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Why this score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        match.explanation,
                        style: TextStyle(fontSize: 14, height: 1.5, color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        if (match.breakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Score breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Points per criterion, 100 in total. A missing preference counts as half.',
                  style: TextStyle(fontSize: 12, color: context.colors.outline),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < match.breakdown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 18),
                  BreakdownBar(criterion: match.breakdown[i], index: i),
                ],
              ],
            ),
          ),
        ],

        if (user.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${user.firstName.isEmpty ? 'them' : user.firstName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(user.bio, style: TextStyle(fontSize: 14, height: 1.5, color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: context.colors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Shown when a hard filter fails (e.g. opened from a received request).
class _IncompatibleCard extends StatelessWidget {
  final List<String> reasons;
  const _IncompatibleCard({required this.reasons});

  @override
  Widget build(BuildContext context) {
    final lines = reasons.isEmpty
        ? const ["Some of your must-haves don't match"]
        : [for (final r in reasons) _reasonTexts[r] ?? r];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: context.colors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Not a compatible roommate',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: context.colors.error, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(fontSize: 13.5, height: 1.4, color: context.colors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

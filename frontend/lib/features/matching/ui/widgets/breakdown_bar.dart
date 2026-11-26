import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/match_result.dart';
import 'score_ring.dart';

const _criterionIcons = {
  'budget': Icons.payments_outlined,
  'sleep_schedule': Icons.bedtime_outlined,
  'cleanliness': Icons.cleaning_services_outlined,
  'noise_tolerance': Icons.volume_up_outlined,
  'smoking': Icons.smoking_rooms_outlined,
  'distance': Icons.place_outlined,
};

/// One criterion of the score: label, animated points bar and both values.
class BreakdownBar extends StatelessWidget {
  final MatchCriterion criterion;
  final int index; // staggers the bars one after the other

  const BreakdownBar({super.key, required this.criterion, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final c = criterion;
    final barColor = c.known
        ? ScoreRing.colorFor(context, (c.ratio * 100).round())
        : context.colors.outlineVariant;
    final textColor = c.known ? context.colors.onSurface : context.colors.outline;
    final delay = index * 120;
    final duration = 700 + delay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_criterionIcons[c.key] ?? Icons.tune, size: 18, color: c.known ? context.colors.primary : context.colors.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            ),
            Text(
              '${_number(c.points)} / ${c.max} pts',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity, // full-width track, the bar fills a fraction of it
          decoration: BoxDecoration(
            color: context.colors.surfaceLow,
            borderRadius: BorderRadius.circular(99),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: c.ratio),
            duration: Duration(milliseconds: duration),
            curve: Interval(delay / duration, 1, curve: Curves.easeOutCubic),
            builder: (context, value, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          criterionDetail(c),
          style: TextStyle(
            fontSize: 12,
            color: context.colors.outline,
            fontStyle: c.known ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// "You: Early bird · Them: Night owl", or why the criterion isn't scored yet.
String criterionDetail(MatchCriterion c) {
  if (!c.known) return 'Not filled in yet (counted as half)';
  if (c.key == 'distance') {
    final km = c.km;
    if (km == null) return 'Distance: Unknown';
    return km == 0 ? 'Same city' : 'Distance between your cities: ${_number(km)} km';
  }
  return 'You: ${formatMatchValue(c.key, c.you)} · Them: ${formatMatchValue(c.key, c.them)}';
}

/// A preference value in words, e.g. budget 450 -> "450 / month", late -> "Night owl".
String formatMatchValue(String key, dynamic value) {
  if (value == null || value == '') return 'Not set';
  switch (key) {
    case 'budget':
      return value is num ? '${_number(value)} / month' : '$value / month';
    case 'sleep_schedule':
      switch (value) {
        case 'early':
          return 'Early bird';
        case 'normal':
          return 'Normal';
        case 'late':
          return 'Night owl';
      }
      return '$value';
    case 'cleanliness':
    case 'noise_tolerance':
      return '$value/5';
    case 'smoking':
      if (value is bool) return value ? 'Smoker' : 'Non-smoker';
      return '$value';
  }
  return '$value';
}

// 20.0 -> "20", 20.8 -> "20.8"
String _number(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

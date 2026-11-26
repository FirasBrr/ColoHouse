import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/match_result.dart';
import 'match_avatar.dart';
import 'score_ring.dart';

/// One compatible roommate: avatar, name, city, short explanation and score.
class MatchCard extends StatelessWidget {
  final MatchResult match;
  final VoidCallback? onTap;
  final bool compact; // home preview: smaller, one line of explanation

  const MatchCard({super.key, required this.match, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final user = match.user;
    final city = match.city ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Row(
              children: [
                MatchAvatar(user: user, radius: compact ? 24 : 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName.isEmpty ? 'ColoHouse member' : user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: context.colors.onSurface,
                              ),
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 16, color: context.colors.primary),
                          ],
                        ],
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14, color: context.colors.outline),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: context.colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (match.explanation.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          match.explanation,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ScoreRing(
                  score: match.score,
                  size: compact ? 48 : 58,
                  strokeWidth: compact ? 5 : 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import '../../auth/models/public_user.dart';

/// Criteria in display order, with their labels.
const matchCriteriaLabels = {
  'budget': 'Budget',
  'sleep_schedule': 'Sleep schedule',
  'cleanliness': 'Cleanliness',
  'noise_tolerance': 'Noise tolerance',
  'smoking': 'Smoking',
  'distance': 'Distance',
};

/// One line of the score breakdown, e.g. budget: 20.8 / 25 points.
class MatchCriterion {
  final String key; // budget | sleep_schedule | cleanliness | noise_tolerance | smoking | distance
  final double points;
  final int max;
  final bool known; // false = one of the two did not fill this preference (counted as half)
  final dynamic you; // my value (int, String, bool or null)
  final dynamic them; // their value
  final double? km; // distance only

  MatchCriterion({
    required this.key,
    required this.points,
    required this.max,
    required this.known,
    this.you,
    this.them,
    this.km,
  });

  String get label => matchCriteriaLabels[key] ?? key;
  double get ratio => max == 0 ? 0 : (points / max).clamp(0, 1).toDouble();

  factory MatchCriterion.fromJson(String key, Map<String, dynamic> json) => MatchCriterion(
        key: key,
        points: (json['points'] as num?)?.toDouble() ?? 0,
        max: json['max'] as int? ?? 0,
        known: json['known'] as bool? ?? false,
        you: json['you'],
        them: json['them'],
        km: (json['km'] as num?)?.toDouble(),
      );
}

/// A compatible roommate (GET /api/matches/) or one person (GET /api/matches/<user_id>/).
class MatchResult {
  final PublicUser user;
  final String? city;
  final int score; // 0-100
  final List<MatchCriterion> breakdown; // in matchCriteriaLabels order
  final String explanation;
  final DateTime computedAt;
  final bool compatible; // detail only (true in the list)
  final List<String> reasons; // detail only: failed hard filters (smoking, budget, move_in_date)

  MatchResult({
    required this.user,
    required this.city,
    required this.score,
    required this.breakdown,
    required this.explanation,
    required this.computedAt,
    this.compatible = true,
    this.reasons = const [],
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    final breakdown = [
      for (final key in matchCriteriaLabels.keys)
        if (raw[key] is Map) MatchCriterion.fromJson(key, (raw[key] as Map).cast<String, dynamic>()),
    ];
    return MatchResult(
      user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
      city: json['city'] as String?,
      score: json['score'] as int? ?? 0,
      breakdown: breakdown,
      explanation: json['explanation'] as String? ?? '',
      computedAt: DateTime.tryParse(json['computed_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      compatible: json['compatible'] as bool? ?? true,
      reasons: (json['reasons'] as List?)?.cast<String>() ?? const [],
    );
  }
}

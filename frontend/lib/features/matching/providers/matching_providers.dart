import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/matching_api.dart';
import '../models/match_result.dart';

final matchingApiProvider = Provider<MatchingApi>((ref) {
  return MatchingApi(ref.read(dioClientProvider).dio);
});

/// Ranked roommates (refresh after the preferences change: ref.invalidate(matchesProvider)).
final matchesProvider = FutureProvider.autoDispose<List<MatchResult>>((ref) async {
  return ref.read(matchingApiProvider).matches();
});

/// Compatibility with one person, by user id.
final matchDetailProvider = FutureProvider.autoDispose.family<MatchResult, int>((ref, userId) async {
  return ref.read(matchingApiProvider).detail(userId);
});

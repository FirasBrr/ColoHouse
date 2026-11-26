import 'package:dio/dio.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/errors/auth_exception.dart';
import '../models/match_result.dart';

class MatchingApi {
  final Dio dio;
  MatchingApi(this.dio);

  /// Compatible roommates, best score first.
  Future<List<MatchResult>> matches({int limit = 20, int? minScore}) async {
    try {
      final res = await dio.get('/matches/', queryParameters: {
        'limit': limit,
        if (minScore != null) 'min_score': minScore,
      });
      return (res.data as List).map((e) => MatchResult.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// Compatibility with one person (404 if they are not in matching and share no request with me).
  Future<MatchResult> detail(int userId) async {
    try {
      final res = await dio.get('/matches/$userId/');
      return MatchResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }
}

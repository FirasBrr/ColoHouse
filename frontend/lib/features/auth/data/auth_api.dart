import 'package:dio/dio.dart';
import '../../../core/errors/auth_exception.dart';
import '../models/user.dart';
import '../../profile/models/roommate_preferences.dart';

class AuthApi {
  final Dio dio;
  AuthApi(this.dio);

  // ---------------- AUTH ----------------

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await dio.post('/auth/register/', data: {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
      });
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<Map<String, String>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      return {
        'access': data['access'] as String,
        'refresh': data['refresh'] as String,
      };
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<User> me() async {
    try {
      final res = await dio.get('/auth/me/');
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<String> refresh(String refreshToken) async {
    try {
      final res = await dio.post('/auth/token/refresh/', data: {
        'refresh': refreshToken,
      });
      return (res.data as Map<String, dynamic>)['access'] as String;
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- PROFILE ----------------

  Future<User> updateProfile(Map<String, dynamic> changes) async {
    try {
      final res = await dio.patch('/auth/me/', data: changes);
      return User.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await dio.delete('/auth/me/');
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- PREFERENCES ----------------

  Future<RoommatePreferences> getPreferences() async {
    try {
      final res = await dio.get('/auth/me/preferences/');
      return RoommatePreferences.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  Future<RoommatePreferences> updatePreferences(
      Map<String, dynamic> changes) async {
    try {
      final res = await dio.patch('/auth/me/preferences/', data: changes);
      return RoommatePreferences.fromJson(res.data);
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- CITIES ----------------

  Future<List<City>> listCities() async {
    try {
      final res = await dio.get('/cities/');
      return (res.data as List)
          .map((e) => City.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AuthException(_errorMessage(e));
    }
  }

  // ---------------- ERRORS ----------------

  String _errorMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (status == 401) {
      if (data is Map && data['detail'] is String) return data['detail'];
      return 'Invalid email or password.';
    }

    if (status == 400 && data is Map) {
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Is the backend running?';
    }

    return 'Something went wrong. Try again.';
  }
}
import 'package:dio/dio.dart';

/// Turns a dio error into a message to show the user (the backend's own message when it sends one).
String apiErrorMessage(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;

  if (status == 400 && data is Map) {
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
  }

  // 401 / 403 / 404 / 503 come as {"detail": "..."}
  if (data is Map && data['detail'] is String) return data['detail'] as String;

  if (status == 401) return 'Invalid email or password.';

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError) {
    return 'Cannot reach the server. Is the backend running?';
  }
  if (e.type == DioExceptionType.receiveTimeout) {
    return 'The server is taking too long to answer. Try again.';
  }

  return 'Something went wrong. Try again.';
}

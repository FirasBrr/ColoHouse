import 'package:dio/dio.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/errors/auth_exception.dart';
import '../models/app_notification.dart';

class NotificationsApi {
  final Dio dio;
  NotificationsApi(this.dio);

  /// This phone receives the user's pushes (token from FirebaseMessaging.getToken()).
  Future<void> registerDevice(String fcmToken) async {
    try {
      await dio.post('/notifications/device/', data: {'fcm_token': fcmToken});
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// Stop pushes to this phone (logout). Only this phone's token is removed.
  Future<void> unregisterDevice(String? fcmToken) async {
    try {
      await dio.delete('/notifications/device/', data: {if (fcmToken != null) 'fcm_token': fcmToken});
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    try {
      final res = await dio.get('/notifications/', queryParameters: {if (unreadOnly) 'unread': 'true'});
      return (res.data as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  Future<int> unreadCount() async {
    try {
      final res = await dio.get('/notifications/unread-count/');
      return (res.data as Map<String, dynamic>)['unread'] as int? ?? 0;
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  Future<void> markRead(int id) async {
    try {
      await dio.post('/notifications/$id/read/');
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  Future<void> markAllRead() async {
    try {
      await dio.post('/notifications/read-all/');
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }
}

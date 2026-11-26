import 'package:dio/dio.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/errors/auth_exception.dart';
import '../models/conversation.dart';

class ChatApi {
  final Dio dio;
  ChatApi(this.dio);

  /// My chats, most recent message first.
  Future<List<Conversation>> conversations() async {
    try {
      final res = await dio.get('/conversations/');
      return (res.data as List).map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }

  /// Open a chat: the server prepares the Firestore document (and marks its notifications read).
  /// 400 = not logged in with Firebase, 404 = not my chat, 503 = Firestore down.
  Future<Conversation> open(int conversationId) async {
    try {
      final res = await dio.get('/conversations/$conversationId/');
      return Conversation.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e), statusCode: e.response?.statusCode);
    }
  }

  /// Tell the server I wrote message `messageId` in Firestore (updates the list, notifies the other person).
  Future<void> messageSent(int conversationId, String messageId) async {
    try {
      await dio.post('/conversations/$conversationId/message-sent/', data: {'message_id': messageId});
    } on DioException catch (e) {
      throw AuthException(apiErrorMessage(e));
    }
  }
}

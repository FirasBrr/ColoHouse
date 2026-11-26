import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/chat_api.dart';
import '../models/conversation.dart';

final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi(ref.read(dioClientProvider).dio);
});

/// Chat list (Messages tab). Invalidated when a message push arrives.
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  return ref.read(chatApiProvider).conversations();
});

/// Opens one chat (prepares its Firestore document on the server).
final openConversationProvider = FutureProvider.autoDispose.family<Conversation, int>((ref, id) async {
  return ref.read(chatApiProvider).open(id);
});

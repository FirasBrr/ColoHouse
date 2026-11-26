import '../../auth/models/public_user.dart';
import '../../housing/models/housing_request.dart';

/// A chat opened by an accepted housing request (GET /api/conversations/).
/// The messages themselves are in Firestore at `$firestorePath/messages`.
class Conversation {
  final int id; // for the API calls
  final int requestId;
  final RequestListingSummary listing;
  final PublicUser otherUser;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int? lastSenderId;
  final String firestorePath; // e.g. "conversations/51fa588d-..." (never build it from id)
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.requestId,
    required this.listing,
    required this.otherUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.firestorePath,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as int,
        requestId: json['request_id'] as int,
        listing: RequestListingSummary.fromJson(json['listing'] as Map<String, dynamic>),
        otherUser: PublicUser.fromJson(json['other_user'] as Map<String, dynamic>),
        lastMessage: json['last_message'] as String? ?? '',
        lastMessageAt: DateTime.tryParse(json['last_message_at'] as String? ?? '')?.toLocal(),
        lastSenderId: json['last_sender_id'] as int?,
        firestorePath: json['firestore_path'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// One Firestore message: conversations/{id}/messages/{messageId}.
/// The fields must stay exactly these (firestore.rules rejects anything else).
class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final DateTime? sentAt; // null while the server timestamp is pending (own message just sent)
  final bool read;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.sentAt,
    required this.read,
  });
}

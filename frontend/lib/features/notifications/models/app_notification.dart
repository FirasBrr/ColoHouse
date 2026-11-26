/// One entry of the notification history (GET /api/notifications/).
class AppNotification {
  final int id;
  final String type; // housing_request | request_accepted | request_declined | new_message
  final String title;
  final String body;
  final Map<String, dynamic> data; // where a tap leads: {"screen": ..., "conversation_id": ...}
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

/// Route of the screen a notification points to. `data` is the push data or the
/// `data` of a notification in the history: {"screen": ..., "conversation_id": ..., "request_id": ...}.
String notificationLocation(Map<String, dynamic> data) {
  switch (data['screen']?.toString()) {
    case 'conversation':
      final id = data['conversation_id'];
      return id != null ? '/conversation/$id' : '/chat?tab=messages';
    case 'received_requests':
      return '/chat?tab=requests';
    case 'sent_requests':
      return '/chat?tab=sent';
    default:
      return '/notifications';
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notifications_api.dart';
import '../models/app_notification.dart';

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.read(dioClientProvider).dio);
});

/// Notification history (bell screen). Invalidated when a push arrives.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.read(notificationsApiProvider).list();
});

/// Red badge on the bell. Recomputed when the logged-in user changes; invalidated when a push arrives.
final unreadCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return 0;
  return ref.read(notificationsApiProvider).unreadCount();
});

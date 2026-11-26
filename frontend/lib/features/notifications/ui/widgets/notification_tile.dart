import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';
import 'notification_time.dart';

/// One card of the notification history.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  // Can be true before notification.isRead is (marked as read on this screen)
  final bool isRead;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = !isRead;
    final (icon, iconColor, iconBackground) = _typeStyle(colors, notification.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // Unread: light primary tint and border, back to a plain card once read
        color: unread
            ? Color.alphaBlend(colors.primary.withValues(alpha: 0.07), colors.surfaceLowest)
            : colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread ? colors.primary.withValues(alpha: 0.25) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              notificationTimeAgo(notification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                                color: unread ? colors.primary : colors.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, height: 1.35, color: colors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Unread dot, fades out once read
                          AnimatedOpacity(
                            opacity: unread ? 1 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon, icon color and circle color of a notification type.
(IconData, Color, Color) _typeStyle(AppPalette colors, String type) {
  return switch (type) {
    'housing_request' => (Icons.home_work_outlined, colors.tertiary, colors.tertiaryFixed),
    'request_accepted' => (Icons.check_rounded, colors.primaryDark, colors.secondaryContainer),
    'request_declined' => (Icons.close_rounded, colors.error, colors.errorContainer),
    'new_message' => (Icons.chat_bubble_outline_rounded, colors.secondary, colors.primary.withValues(alpha: 0.12)),
    _ => (Icons.notifications_outlined, colors.onSurfaceVariant, colors.surfaceLow),
  };
}

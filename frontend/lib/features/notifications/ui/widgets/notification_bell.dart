import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/notifications_providers.dart';

/// Bell of the home app bar: red badge with the unread count, opens the history.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  // Last count shown, so the badge keeps its number while it shrinks away
  int _lastCount = 0;

  Future<void> _open() async {
    await context.push('/notifications');
    // Back from the history (or a chat opened from it): the count may have changed
    if (mounted) ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Hidden while loading or on error; a refresh keeps the previous count
    final count = ref.watch(unreadCountProvider).maybeWhen(data: (c) => c, orElse: () => 0);
    if (count > 0) _lastCount = count;
    final label = _lastCount > 9 ? '9+' : '$_lastCount';

    return IconButton(
      tooltip: count > 0 ? 'Notifications ($count unread)' : 'Notifications',
      onPressed: _open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            count > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
            color: context.colors.onSurfaceVariant,
          ),
          // Directional so the badge follows the bell's corner in Arabic (RTL)
          PositionedDirectional(
            top: -5,
            end: -7,
            child: AnimatedScale(
              scale: count > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              curve: count > 0 ? Curves.easeOutBack : Curves.easeIn,
              child: Container(
                height: 18,
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  borderRadius: BorderRadius.circular(9),
                  // Thin ring in the bar color so the badge stands out from the bell
                  border: Border.all(color: context.colors.surfaceLowest, width: 1.5),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

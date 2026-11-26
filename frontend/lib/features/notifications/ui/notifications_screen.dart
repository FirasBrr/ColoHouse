import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/push/notification_target.dart';
import '../../../core/theme/app_colors.dart';
import '../models/app_notification.dart';
import '../providers/notifications_providers.dart';
import 'widgets/notification_tile.dart';
import 'widgets/notification_time.dart';

/// Notification history (bell icon of the home app bar).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Marked as read on this screen: shown as read right away, before the list is fetched again
  final Set<int> _readIds = {};
  bool _markingAll = false;
  bool _opening = false;

  bool _isRead(AppNotification n) => n.isRead || _readIds.contains(n.id);

  Future<void> _refresh() async {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
    try {
      await ref.read(notificationsProvider.future);
    } catch (_) {
      // The list shows the error state
    }
  }

  Future<void> _markRead(int id) async {
    setState(() => _readIds.add(id));
    // Container kept aside: going to a tab (context.go) disposes this screen before the call ends
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(notificationsApiProvider).markRead(id);
      container.invalidate(unreadCountProvider);
    } on AuthException {
      if (mounted) setState(() => _readIds.remove(id));
    }
  }

  Future<void> _markAllRead(List<AppNotification> items) async {
    final ids = items.where((n) => !_isRead(n)).map((n) => n.id).toSet();
    if (ids.isEmpty) return;
    setState(() {
      _markingAll = true;
      _readIds.addAll(ids);
    });
    try {
      await ref.read(notificationsApiProvider).markAllRead();
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _readIds.removeAll(ids));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: context.colors.error),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (_opening) return;
    if (!_isRead(n)) unawaited(_markRead(n.id));

    final location = notificationLocation(n.data);
    if (location == '/notifications') return;
    if (location.startsWith('/chat')) {
      // Requests / sent / messages are tabs of the home shell
      context.go(location);
      return;
    }

    _opening = true;
    try {
      await context.push(location);
    } finally {
      _opening = false;
    }
    // Back from the chat: opening it marked its message notifications as read
    if (!mounted) return;
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final loaded = notificationsAsync.maybeWhen(data: (items) => items, orElse: () => const <AppNotification>[]);
    final hasUnread = loaded.any((n) => !_isRead(n));

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const BackButtonIcon(),
          onPressed: _back,
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded),
            color: context.colors.primary,
            onPressed: hasUnread && !_markingAll ? () => _markAllRead(loaded) : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e is AuthException ? e.message : 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) => items.isEmpty ? _EmptyState(onRefresh: _refresh) : _buildList(items),
      ),
    );
  }

  Widget _buildList(List<AppNotification> items) {
    final now = DateTime.now();
    final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Flat rows for ListView.builder: a String is a section header ("Today" / "Earlier")
    final rows = <Object>[];
    String? section;
    for (final n in sorted) {
      final label = isSameDay(n.createdAt, now) ? 'Today' : 'Earlier';
      if (label != section) {
        rows.add(label);
        section = label;
      }
      rows.add(n);
    }

    return RefreshIndicator(
      color: context.colors.primary,
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) return _SectionHeader(label: row, first: index == 0);
          final n = row as AppNotification;
          return Padding(
            key: ValueKey(n.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _FadeSlideIn(
              index: index,
              child: NotificationTile(
                notification: n,
                isRead: _isRead(n),
                onTap: () => _open(n),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool first;

  const _SectionHeader({required this.label, required this.first});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 8 : 14, 4, 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Cards fade and slide in when the list appears, a bit later for each row.
class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + 50 * index.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.colors.primary,
      onRefresh: onRefresh,
      // Scrollable so pull-to-refresh also works on the empty screen
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: context.colors.secondaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_none_rounded, size: 48, color: context.colors.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New housing requests, answers to your requests and new messages will show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.outline, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: context.colors.outline),
            const SizedBox(height: 16),
            Text(
              "Couldn't load your notifications",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.colors.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.outline, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

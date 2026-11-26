import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/chat_providers.dart';
import '../../features/notifications/providers/notifications_providers.dart';
import '../router/app_router.dart';
import 'notification_target.dart';

/// Pushes received while the app is in the background or closed: Android shows them itself
/// (they carry a notification); the tap is handled by onMessageOpenedApp / getInitialMessage.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  // Logout unregisters this phone first. Set from here so that authProvider never reads this
  // provider (it listens to authProvider: reading it back would be a circular dependency).
  ref.read(authProvider.notifier).beforeLogout = service.unregister;
  ref.listen<AuthState>(
    authProvider,
    (previous, next) => service._onAuthChanged(previous, next),
    fireImmediately: true,
  );
  ref.onDispose(service._dispose);
  return service;
});

/// Push notifications (Firebase Cloud Messaging):
/// - after login: asks the permission, sends this phone's token to the backend;
/// - app open: shows the push as a local notification and refreshes the lists / bell badge;
/// - tap (push or local notification): opens the screen given by `data.screen`;
/// - logout: the backend forgets this phone ([unregister]).
class PushService {
  PushService(this._ref);

  final Ref _ref;

  // Same id as the backend (notifications/services.py) and AndroidManifest.xml
  static const channel = AndroidNotificationChannel(
    'colohouse_default',
    'Requests and messages',
    description: 'Housing requests, answers and chat messages',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final _ready = Completer<void>();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<String>? _tokenRefresh;
  AppLifecycleListener? _lifecycle;
  String? _token;
  bool _started = false;

  // A notification tapped while the app was closed or logged out: opened after login
  Map<String, dynamic>? _pendingTarget;

  int? _activeConversationId;

  /// The chat currently on screen (set by the conversation screen): its message pushes are not shown,
  /// and the ones already in the notification shade are removed when it opens.
  int? get activeConversationId => _activeConversationId;
  set activeConversationId(int? id) {
    _activeConversationId = id;
    if (id != null) _clearConversationNotifications(id);
  }

  /// Removes a chat's notifications from the shade (local ones and the ones Android showed in the background).
  Future<void> _clearConversationNotifications(int conversationId) async {
    final tag = 'conversation-$conversationId';
    try {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final active = await android?.getActiveNotifications() ?? const [];
      for (final notification in active) {
        if (notification.tag == tag) await _local.cancel(id: notification.id ?? 0, tag: tag);
      }
    } catch (_) {}
  }

  /// Called once in main(), before runApp.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) => _openPayload(response.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _subscriptions.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) => openTarget(message.data)));
      // Pushes received in the background are not delivered to the app: refresh when it comes back
      _lifecycle = AppLifecycleListener(onResume: _onResume);

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingTarget = initial.data;
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        _pendingTarget = _decode(launch.notificationResponse?.payload) ?? _pendingTarget;
      }
    } catch (e) {
      debugPrint('Push init failed: $e');
    } finally {
      _ready.complete();
    }
  }

  void _onAuthChanged(AuthState? previous, AuthState next) {
    if (next.status == AuthStatus.authenticated && previous?.status != AuthStatus.authenticated) {
      _register();
    }
  }

  Future<void> _register() async {
    await _ready.future;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // The backend targets FCM registration tokens (firebase-admin `token=`). The newer
      // register()/onRegistered API gives an installation id (FID) instead: switching means
      // changing both sides together, so the token API is kept on purpose.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) {
        _token = token;
        await _ref.read(notificationsApiProvider).registerDevice(token);
      }
      // ignore: deprecated_member_use
      _tokenRefresh ??= messaging.onTokenRefresh.listen((token) async {
        _token = token;
        if (_ref.read(authProvider).status != AuthStatus.authenticated) return;
        try {
          await _ref.read(notificationsApiProvider).registerDevice(token);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }

    final target = _pendingTarget;
    if (target != null) {
      _pendingTarget = null;
      // Let the router finish its redirect to the home screen first
      Future.delayed(const Duration(milliseconds: 400), () => openTarget(target));
    }
  }

  /// Logout: this phone stops receiving the user's pushes. Called while the tokens are still valid.
  /// notifyServer: false when the account was just deleted (the server already forgot the phone).
  Future<void> unregister({bool notifyServer = true}) async {
    final token = _token;
    _pendingTarget = null;
    try {
      // The next account on this phone must not see (or tap) this account's notifications
      await _local.cancelAll();
    } catch (_) {}
    if (notifyServer) {
      try {
        await _ref.read(notificationsApiProvider).unregisterDevice(token);
      } catch (_) {}
    }
    try {
      // Even if the call above failed (offline), the old token can no longer receive pushes
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString();
    _refreshData(type);

    if (type == 'new_message' && data['conversation_id'] == activeConversationId?.toString()) {
      // The user is reading this chat: no banner, and the message does not count in the bell badge
      final notificationId = int.tryParse('${data['notification_id']}');
      if (notificationId != null) _markRead(notificationId);
      return;
    }
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    _local.show(
      id: int.tryParse('${data['notification_id']}') ?? message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: type == 'new_message' ? 'conversation-${data['conversation_id']}' : null,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Back in the app: the badge and lists may be outdated, and the open chat's new messages are read.
  void _onResume() {
    if (_ref.read(authProvider).status != AuthStatus.authenticated) return;
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(conversationsProvider);
    _ref.invalidate(receivedRequestsProvider);
    _ref.invalidate(sentRequestsProvider);
    final conversationId = _activeConversationId;
    if (conversationId != null) {
      _clearConversationNotifications(conversationId);
      _markConversationRead(conversationId);
    }
  }

  /// Opening a chat on the server marks its message notifications as read.
  Future<void> _markConversationRead(int conversationId) async {
    try {
      await _ref.read(chatApiProvider).open(conversationId);
      _ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  /// Lists that a new notification makes outdated.
  void _refreshData(String? type) {
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(notificationsProvider);
    switch (type) {
      case 'new_message':
        _ref.invalidate(conversationsProvider);
      case 'housing_request':
        _ref.invalidate(receivedRequestsProvider);
      case 'request_accepted':
        _ref.invalidate(sentRequestsProvider);
        _ref.invalidate(conversationsProvider);
      case 'request_declined':
        _ref.invalidate(sentRequestsProvider);
    }
  }

  void _openPayload(String? payload) {
    final data = _decode(payload);
    if (data != null) openTarget(data);
  }

  Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return (jsonDecode(payload) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Opens the screen a notification points to (push tap, local notification tap).
  void openTarget(Map<String, dynamic> data) {
    if (_ref.read(authProvider).status != AuthStatus.authenticated) {
      _pendingTarget = data;
      return;
    }
    final notificationId = int.tryParse('${data['notification_id']}');
    if (notificationId != null) _markRead(notificationId);
    _refreshData(data['type']?.toString());

    final location = notificationLocation(data);
    final router = _ref.read(routerProvider);
    if (location.startsWith('/conversation/') || location == '/notifications') {
      // Already on that screen (e.g. the chat is open): do not open a second copy on top.
      // After a push, go_router keeps the base uri: the screen on top is the last match.
      final onTop = router.routerDelegate.currentConfiguration.last.matchedLocation;
      if (onTop == location) return;
      router.push(location);
    } else {
      router.go(location);
    }
  }

  Future<void> _markRead(int notificationId) async {
    try {
      await _ref.read(notificationsApiProvider).markRead(notificationId);
      _ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  void _dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _tokenRefresh?.cancel();
    _lifecycle?.dispose();
  }
}

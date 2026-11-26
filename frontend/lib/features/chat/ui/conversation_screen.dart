import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/push/push_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../models/conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_format.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_states.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_composer.dart';

/// One chat: the server opens it (FutureBuilder), then the messages come live from Firestore.
class ConversationScreen extends ConsumerStatefulWidget {
  final int conversationId;
  const ConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  // Kept here: ref can't be used in dispose()
  late final PushService _push;
  late final String? _myUid;
  Future<Conversation>? _open;
  // Header from the chat list while the server opens the chat
  Conversation? _preview;

  @override
  void initState() {
    super.initState();
    _push = ref.read(pushServiceProvider);
    _myUid = ref.read(firebaseAuthServiceProvider).uid;
    if (ref.exists(conversationsProvider)) {
      _preview = ref
          .read(conversationsProvider)
          .valueOrNull
          ?.where((c) => c.id == widget.conversationId)
          .firstOrNull;
    }
    if (_myUid != null) _open = _openChat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // While this chat is on top, its message pushes are not shown (they are again when
    // the listing or another chat is opened over it)
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (onTop) {
      _push.activeConversationId = widget.conversationId;
    } else if (_push.activeConversationId == widget.conversationId) {
      _push.activeConversationId = null;
    }
  }

  @override
  void dispose() {
    if (_push.activeConversationId == widget.conversationId) _push.activeConversationId = null;
    super.dispose();
  }

  Future<Conversation> _openChat() async {
    final conversation = await ref.read(chatApiProvider).open(widget.conversationId);
    // Opening the chat marked its message notifications as read (bell badge)
    if (mounted) {
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
    }
    return conversation;
  }

  void _retry() => setState(() => _open = _openChat());

  // The router goes to /login by itself
  void _logout() => ref.read(authProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Conversation>(
      future: _open,
      builder: (context, snapshot) {
        final conversation = snapshot.data ?? _preview;
        return Scaffold(
          backgroundColor: context.colors.surfaceLowest,
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            title: conversation == null
                ? const Text('Chat')
                : _ChatHeader(
                    conversation: conversation,
                    onTap: () => context.push('/listing/${conversation.listing.id}'),
                  ),
          ),
          body: _buildBody(snapshot),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<Conversation> snapshot) {
    final myUid = _myUid;
    if (myUid == null) return _LoginRequired(onLogout: _logout);
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      final status = error is AuthException ? error.statusCode : null;
      // 400: this account is not logged in with Firebase, which the chat needs
      if (status == 400) return _LoginRequired(onLogout: _logout);
      // 404: the chat does not exist (anymore) or is not mine: retrying cannot help
      if (status == 404) return const _ChatUnavailable();
      final message = error is AuthException ? error.message : 'Could not open this chat. Try again.';
      return ChatErrorState(message: message, onRetry: _retry);
    }
    return _ChatView(conversation: snapshot.data!, myUid: myUid);
  }
}

/// The chat was deleted (e.g. the other account was removed) or is not this user's.
class _ChatUnavailable extends StatelessWidget {
  const _ChatUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: context.colors.outline),
            const SizedBox(height: 16),
            Text(
              'This chat is no longer available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.onSurface),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go('/chat?tab=messages'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to my chats'),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar title: avatar, name and listing (tap = open the listing).
class _ChatHeader extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ChatHeader({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4).copyWith(right: 8),
        child: Row(
          children: [
            Hero(
              tag: chatAvatarHeroTag(conversation.id),
              child: ChatAvatar(user: conversation.otherUser, radius: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chatName(conversation.otherUser),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                  Row(
                    children: [
                      Icon(Icons.home_outlined, size: 12, color: colors.secondary),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          conversation.listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: colors.outline),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chat needs a Firebase login (email or Google): old sessions must log in again.
class _LoginRequired extends StatelessWidget {
  final VoidCallback onLogout;

  const _LoginRequired({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: colors.tertiaryFixed, shape: BoxShape.circle),
              child: Icon(Icons.lock_outline, size: 40, color: colors.tertiary),
            ),
            const SizedBox(height: 20),
            Text(
              'Log in again to chat',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'The chat needs a login with your email or Google account. Log out, then log in again with email or Google.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live messages (Firestore) + composer, once the server has opened the chat.
class _ChatView extends StatefulWidget {
  final Conversation conversation;
  final String myUid;

  const _ChatView({required this.conversation, required this.myUid});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  // Newest first (index 0 = bottom of the reversed list); my pending messages come first
  List<ChatMessage> _messages = const [];
  Map<String, int> _indexById = const {};
  bool _loading = true;
  String? _error;

  // Messages already marked as read (one update per message)
  final _markedRead = <String>{};
  bool _appResumed = true;
  bool _onTop = true;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('${widget.conversation.firestorePath}/messages');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appResumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _listen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not seen while the listing (or another chat) is opened over this one
    _onTop = ModalRoute.isCurrentOf(context) ?? true;
    _markAsRead();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _markAsRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _collection
        .orderBy('sent_at', descending: true)
        .snapshots()
        .listen(_onSnapshot, onError: _onError);
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _listen();
  }

  ChatMessage _toMessage(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final sentAt = data['sent_at'];
    return ChatMessage(
      id: doc.id,
      senderUid: data['sender_uid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: sentAt is Timestamp ? sentAt.toDate() : null,
      read: data['read'] == true,
    );
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;
    final all = snapshot.docs.map(_toMessage).toList();
    // A message without server time yet is my own, just sent: keep it at the bottom
    final messages = [
      ...all.where((m) => m.sentAt == null),
      ...all.where((m) => m.sentAt != null),
    ];
    setState(() {
      _messages = messages;
      _indexById = {for (var i = 0; i < messages.length; i++) messages[i].id: i};
      _loading = false;
      _error = null;
    });
    _markAsRead();
  }

  void _onError(Object error) {
    if (!mounted) return;
    final denied = error is FirebaseException && error.code == 'permission-denied';
    setState(() {
      _loading = false;
      _error = denied
          ? 'You don\'t have access to this chat. Log out and log in again, then retry.'
          : 'Could not load the messages. Check your connection and try again.';
    });
  }

  /// The other person's unread messages, while this chat is really on screen.
  void _markAsRead() {
    if (!_appResumed || !_onTop) return;
    for (final message in _messages) {
      if (message.senderUid == widget.myUid || message.read) continue;
      if (!_markedRead.add(message.id)) continue;
      _markRead(message.id);
    }
  }

  Future<void> _markRead(String messageId) async {
    try {
      // Only {'read': true}: the rules refuse any other change
      await _collection.doc(messageId).update({'read': true});
    } catch (e) {
      debugPrint('Could not mark message $messageId as read: $e');
    }
  }

  Future<bool> _send(String text) async {
    if (text.runes.length > MessageComposer.maxLength) {
      _showError('Your message is too long (${MessageComposer.maxLength} characters max).');
      return false;
    }
    // Captured now: the user may leave the chat before the server call ends
    final container = ProviderScope.containerOf(context, listen: false);
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }

    // Not awaited: Firestore shows the message at once (pending) and sends it when the phone is
    // online; waiting for the server would block the composer while offline.
    // Exactly these 4 fields, or firestore.rules rejects the message.
    final doc = _collection.doc();
    doc.set({
      'sender_uid': widget.myUid,
      'text': text,
      'sent_at': FieldValue.serverTimestamp(),
      'read': false,
    }).then(
      (_) => _notifyServer(container, doc.id),
      onError: (Object e) {
        final denied = e is FirebaseException && e.code == 'permission-denied';
        _showError(denied
            ? 'You can\'t send messages in this chat. Log out and log in again.'
            : 'Message not sent. Check your connection and try again.');
      },
    );
    return true;
  }

  /// The server updates the chat list and sends the push to the other person.
  Future<void> _notifyServer(ProviderContainer container, String messageId) async {
    try {
      await container.read(chatApiProvider).messageSent(widget.conversation.id, messageId);
    } catch (e) {
      // The message is already saved in Firestore: only the push / list preview is missed
      debugPrint('message-sent failed for $messageId: $e');
    }
    container.invalidate(conversationsProvider);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.colors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildMessages(context)),
        MessageComposer(onSend: _send, enabled: _error == null),
      ],
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ChatErrorState(message: _error!, onRetry: _retry);
    if (_messages.isEmpty) {
      final name = widget.conversation.otherUser.firstName;
      return ChatEmptyState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello 👋',
        message: 'Start the conversation${name.isEmpty ? '' : ' with $name'} about "${widget.conversation.listing.title}".',
      );
    }

    final lastRead = _messages.indexWhere((m) => m.senderUid == widget.myUid && m.read);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _messages.length,
      // Keeps each bubble's state (its fade when sent) when new messages are inserted
      findChildIndexCallback: (key) => key is ValueKey<String> ? _indexById[key.value] : null,
      itemBuilder: (context, index) => _buildItem(context, index, lastRead),
    );
  }

  Widget _buildItem(BuildContext context, int index, int lastRead) {
    final now = DateTime.now();
    final message = _messages[index];
    final date = message.sentAt ?? now;
    final older = index + 1 < _messages.length ? _messages[index + 1] : null;
    final newDay = older == null || !isSameDay(older.sentAt ?? now, date);
    // Consecutive messages of the same person sit closer together
    final grouped = older != null && !newDay && older.senderUid == message.senderUid;

    return Column(
      key: ValueKey<String>(message.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newDay) DaySeparator(label: dayLabel(context, date)),
        Padding(
          padding: EdgeInsets.only(top: grouped ? 4 : 12),
          child: MessageBubble(
            message: message,
            isMine: message.senderUid == widget.myUid,
            showRead: index == lastRead,
          ),
        ),
      ],
    );
  }
}

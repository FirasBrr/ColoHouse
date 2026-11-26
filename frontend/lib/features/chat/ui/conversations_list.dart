import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_format.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_states.dart';

/// Messages tab: my chats, the most recent message first.
class ConversationsList extends ConsumerWidget {
  const ConversationsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final myId = ref.watch(authProvider.select((state) => state.user?.id));
    Future<void> refresh() => ref.refresh(conversationsProvider.future).then<void>((_) {}, onError: (_) {});

    return conversationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ChatErrorState(
        message: e is AuthException ? e.message : 'Could not load your chats.',
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
      data: (conversations) {
        if (conversations.isEmpty) {
          return RefreshableFill(
            onRefresh: refresh,
            child: const ChatEmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message: 'When a host accepts a request, your chat opens here.',
            ),
          );
        }

        return RefreshIndicator(
          color: context.colors.primary,
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: conversations.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ConversationTile(conversation: conversations[index], myId: myId),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int? myId;

  const _ConversationTile({required this.conversation, required this.myId});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = conversation;
    final hasMessage = c.lastMessage.isNotEmpty;
    final fromMe = myId != null && c.lastSenderId == myId;
    final preview = hasMessage ? (fromMe ? 'You: ${c.lastMessage}' : c.lastMessage) : 'Say hello 👋';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/conversation/${c.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // No flight from the Chat tab while another tab is on screen (its branch is offstage)
                HeroMode(
                  enabled: TickerMode.valuesOf(context).enabled,
                  child: Hero(
                    tag: chatAvatarHeroTag(c.id),
                    child: ChatAvatar(user: c.otherUser, radius: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chatName(c.otherUser),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colors.onSurface),
                            ),
                          ),
                          if (c.otherUser.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 14, color: colors.primary),
                          ],
                          const Spacer(),
                          const SizedBox(width: 8),
                          Text(
                            relativeTime(context, c.lastMessageAt ?? c.createdAt),
                            style: TextStyle(fontSize: 11, color: colors.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.home_outlined, size: 13, color: colors.secondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              c.listing.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: hasMessage ? colors.onSurfaceVariant : colors.primary,
                          fontWeight: hasMessage ? FontWeight.normal : FontWeight.w600,
                        ),
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

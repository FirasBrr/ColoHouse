import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/auth_exception.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../chat/providers/chat_providers.dart';
import '../chat/ui/conversations_list.dart';
import '../chat/ui/widgets/chat_states.dart';
import '../housing/models/housing_request.dart';
import 'sent_requests_tab.dart';
import 'widgets/home_app_bar.dart';

class ChatTab extends ConsumerStatefulWidget {
  // 'messages' | 'requests' | 'sent' (from /chat?tab=..., e.g. a notification tap)
  final String? initialTab;
  const ChatTab({super.key, this.initialTab});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> with SingleTickerProviderStateMixin {
  static const _tabNames = ['messages', 'requests', 'sent'];
  late final TabController _tabs;

  int _indexOf(String? tab) {
    final index = _tabNames.indexOf(tab ?? '');
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabNames.length, vsync: this, initialIndex: _indexOf(widget.initialTab));
    _tabs.addListener(_onTabChanged);
  }

  // A notification opened /chat?tab=... while this tab was already built
  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      final index = _indexOf(widget.initialTab);
      if (index != _tabs.index) _tabs.animateTo(index);
    }
  }

  // Keeps ?tab= in sync with the visible tab, so the next notification for another tab switches again
  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final name = _tabNames[_tabs.index];
    if (name == (widget.initialTab ?? 'messages')) return;
    context.go('/chat?tab=$name');
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final pendingCount = ref.watch(receivedRequestsProvider).valueOrNull?.where((r) => r.status == 'pending').length ?? 0;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          HomeAppBar(user: user),
          TabBar(
            controller: _tabs,
            indicatorColor: context.colors.primary,
            labelColor: context.colors.primary,
            unselectedLabelColor: context.colors.outline,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'Messages'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Requests'),
                    // Pending requests waiting for my answer
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: context.colors.tertiary, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          '$pendingCount',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.surfaceLowest),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Sent'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                ConversationsList(),
                _InboxDashboard(),
                SentRequestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// RECEIVED REQUESTS (requests on my listings)
// ==========================================
class _InboxDashboard extends ConsumerWidget {
  const _InboxDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(receivedRequestsProvider);
    Future<void> refresh() => ref.refresh(receivedRequestsProvider.future).then<void>((_) {}, onError: (_) {});

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ChatErrorState(
        message: e is AuthException ? e.message : 'Could not load your requests.',
        onRetry: () => ref.invalidate(receivedRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return RefreshableFill(
            onRefresh: refresh,
            child: const ChatEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No requests yet',
              message: 'When someone asks for one of your rooms, the request shows up here.',
            ),
          );
        }

        // The most recent pending request is pinned as "Action Required"
        final pendingReq = requests.where((r) => r.status == 'pending').firstOrNull;

        return RefreshIndicator(
          color: context.colors.primary,
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: requests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader(context, ref, pendingReq);
              return _buildThreadCard(context, ref, requests[index - 1]);
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, HousingRequest? pendingReq) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Pinned Pending Request Banner ---
        if (pendingReq != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: context.colors.tertiary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text('INCOMING REQUEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.tertiary, letterSpacing: 1)),
                      ],
                    ),
                    Text('Action Required', style: TextStyle(fontSize: 11, color: context.colors.outline)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Request for ${pendingReq.listing.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text('From: ${pendingReq.senderName}', style: TextStyle(fontSize: 12, color: context.colors.outline)),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showActionDialog(context, ref, pendingReq),
                    style: TextButton.styleFrom(
                      backgroundColor: context.colors.surfaceLowest,
                      foregroundColor: context.colors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Review Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        Text('RECEIVED REQUESTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: context.colors.outline)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildThreadCard(BuildContext context, WidgetRef ref, HousingRequest req) {
    bool isPending = req.status == 'pending';
    bool isAccepted = req.status == 'accepted';
    final conversationId = req.conversationId;
    final senderId = req.senderId;

    return InkWell(
      onTap: () => _showActionDialog(context, ref, req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: isPending ? Border.all(color: context.colors.tertiary.withValues(alpha: 0.3), width: 1.5) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: context.colors.surfaceLow,
              child: Text(
                req.senderName.isNotEmpty ? req.senderName[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          req.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPending ? context.colors.tertiary.withValues(alpha: 0.1) : isAccepted ? context.colors.primary.withValues(alpha: 0.1) : context.colors.surfaceLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          req.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isPending ? context.colors.tertiary : isAccepted ? context.colors.primary : context.colors.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Wants: ${req.listing.title}', style: TextStyle(fontSize: 12, color: context.colors.secondary, fontWeight: FontWeight.w600)),
                  if (req.message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${req.message}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPending ? context.colors.onSurface : context.colors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleAction(context, ref, req, 'decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.error,
                              side: BorderSide(color: context.colors.error),
                              minimumSize: const Size(0, 36),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Decline', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _handleAction(context, ref, req, 'accept'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Accept', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isAccepted && req.contact != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_open, size: 14, color: context.colors.primary),
                              const SizedBox(width: 6),
                              Text('Contact Unlocked', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.primary, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Phone: ${req.contact!['sender_phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  // Compatibility with the sender (roommate matching) and the chat once accepted
                  if (senderId != null || conversationId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (senderId != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/roommates/$senderId'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.colors.primary,
                                side: BorderSide(color: context.colors.outlineVariant),
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.people_alt_outlined, size: 16),
                              label: const Text('Compatibility', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        if (senderId != null && conversationId != null) const SizedBox(width: 8),
                        if (conversationId != null)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push('/conversation/$conversationId'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: const Text('Open chat', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionDialog(BuildContext context, WidgetRef ref, HousingRequest req) {
    if (req.status != 'pending') return; // Only pending requests can be answered
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request from ${req.senderName}'),
        content: Text(req.message.isEmpty ? 'No message.' : '"${req.message}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _handleAction(context, ref, req, 'decline');
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleAction(context, ref, req, 'accept');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, HousingRequest req, String action) async {
    if (!_requestsInFlight.add(req.id)) return; // double tap: the first call is still running
    // Read before the await: switching tab meanwhile disposes this widget and its ref
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      if (action == 'accept') {
        await container.read(authRepoProvider).api.acceptRequest(req.id);
      } else {
        await container.read(authRepoProvider).api.declineRequest(req.id);
      }
      container.invalidate(receivedRequestsProvider);
      // Accepting opens the chat
      if (action == 'accept') container.invalidate(conversationsProvider);
      if (context.mounted) {
        final text = action == 'accept' ? 'Request accepted. You can now chat with ${req.senderName}.' : 'Request declined.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      }
    } catch (e) {
      if (context.mounted) {
        final text = e is AuthException ? e.message : 'Something went wrong. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: context.colors.error));
      }
    } finally {
      _requestsInFlight.remove(req.id);
    }
  }
}

// Requests whose accept/decline call is running (ignores a second tap meanwhile)
final _requestsInFlight = <int>{};

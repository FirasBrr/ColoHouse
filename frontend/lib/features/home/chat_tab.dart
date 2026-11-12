import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../housing/models/housing_request.dart';
import 'sent_requests_tab.dart';
import 'widgets/home_app_bar.dart';

class ChatTab extends ConsumerWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final receivedRequests = ref.watch(receivedRequestsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          HomeAppBar(user: user),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.outline,
                    tabs: [
                      Tab(text: 'Inbox'),
                      Tab(text: 'Sent'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _InboxDashboard(), // New UI
                        const SentRequestsTab(), // Your existing sent logic
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// THE NEW INBOX DASHBOARD UI
// ==========================================
class _InboxDashboard extends ConsumerWidget {
  const _InboxDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(receivedRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        // Find the most recent pending request to show as the "Pinned Application"
        final pendingReq = requests.where((r) => r.status == 'pending').firstOrNull;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // --- Pinned Pending Request Banner ---
            if (pendingReq != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
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
                              decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            const Text('INCOMING REQUEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary, letterSpacing: 1)),
                          ],
                        ),
                        const Text('Action Required', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Request for ${pendingReq.listing.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('From: ${pendingReq.senderName}', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Scroll down or navigate to the Received list
                          // For now, the requests are listed below this banner
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceLowest,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Review Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_downward, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Active Conversations (Received Requests) ---
            const Text('ACTIVE CONVERSATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.outline)),
            const SizedBox(height: 12),

            if (requests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No messages yet.', style: TextStyle(color: AppColors.outline)),
                ),
              )
            else
              ...requests.map((req) => _buildThreadCard(context, ref, req)),
          ],
        );
      },
    );
  }

  Widget _buildThreadCard(BuildContext context, WidgetRef ref, HousingRequest req) {
    bool isPending = req.status == 'pending';
    bool isAccepted = req.status == 'accepted';
    bool isDeclined = req.status == 'declined';

    return InkWell(
      onTap: () => _showActionDialog(context, ref, req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          border: isPending ? Border.all(color: AppColors.tertiary.withValues(alpha: 0.3), width: 1.5) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surfaceLow,
              child: Text(
                req.senderName.isNotEmpty ? req.senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(req.senderName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending ? AppColors.tertiary.withValues(alpha: 0.1) : isAccepted ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              req.status.toUpperCase(), 
                              style: TextStyle(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold,
                                color: isPending ? AppColors.tertiary : isAccepted ? AppColors.primary : AppColors.outline,
                              )
                            ),
                          ),
                        ],
                      ),
                      // Use "Today" or a formatted date
                      Text(
                        _formatDate(req.id), 
                        style: TextStyle(fontSize: 11, color: isPending ? AppColors.tertiary : AppColors.outline)
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Wants: ${req.listing.title}', style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '"${req.message}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13, 
                      color: isPending ? AppColors.onSurface : AppColors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleAction(context, ref, req, 'decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
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
                        color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_open, size: 14, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text('Contact Unlocked', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Phone: ${req.contact!['sender_phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
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
    if (req.status != 'pending') return; // Only show dialog for pending
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request from ${req.senderName}'),
        content: Text('"${req.message}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, HousingRequest req, String action) async {
    try {
      if (action == 'accept') {
        await ref.read(authRepoProvider).api.acceptRequest(req.id);
      } else {
        await ref.read(authRepoProvider).api.declineRequest(req.id);
      }
      ref.invalidate(receivedRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $action successful!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  String _formatDate(int id) {
    // Just a small helper to give each card a pseudo-date for UI purposes
    // In the future, use the actual createdAt timestamp
    return 'Today'; 
  }
}
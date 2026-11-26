import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/errors/auth_exception.dart';
import '../auth/providers/auth_provider.dart';
import '../chat/ui/widgets/chat_states.dart';
import '../housing/models/housing_request.dart';

class SentRequestsTab extends ConsumerWidget {
  const SentRequestsTab({super.key});

  Future<void> _cancelRequest(BuildContext context, WidgetRef ref, int requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to withdraw this request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel')
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    if (!_cancelsInFlight.add(requestId)) return;
    // Read before the await: switching tab meanwhile disposes this widget and its ref
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(authRepoProvider).api.cancelRequest(requestId);
      container.invalidate(sentRequestsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
        );
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: context.colors.error),
        );
      }
    } finally {
      _cancelsInFlight.remove(requestId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(sentRequestsProvider);
    Future<void> refresh() => ref.refresh(sentRequestsProvider.future).then<void>((_) {}, onError: (_) {});

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ChatErrorState(
        message: e is AuthException ? e.message : 'Could not load your sent requests.',
        onRetry: () => ref.invalidate(sentRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return RefreshableFill(
            onRefresh: refresh,
            child: const ChatEmptyState(
              icon: Icons.outbox_outlined,
              title: 'No sent requests',
              message: 'When you request a room, it will appear here.',
            ),
          );
        }

        return RefreshIndicator(
          color: context.colors.primary,
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SentRequestCard(
                  request: req,
                  onCancel: () => _cancelRequest(context, ref, req.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final HousingRequest request;
  final VoidCallback onCancel;

  const _SentRequestCard({required this.request, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    bool isPending = request.status == 'pending';
    bool isAccepted = request.status == 'accepted';
    final conversationId = request.conversationId;
    // pending = amber, accepted / completed = green, declined / cancelled = red
    final statusColor = isPending
        ? context.colors.tertiary
        : isAccepted || request.status == 'completed'
            ? context.colors.primary
            : context.colors.error;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: request.listing.photo != null
                      ? Image.network(
                          request.listing.photo!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(context),
                        )
                      : _photoPlaceholder(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text('To: ${request.ownerName}', style: TextStyle(fontSize: 12, color: context.colors.outline)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          if (isAccepted && request.contact != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: context.colors.primary),
                        const SizedBox(width: 8),
                        Text('Request Accepted!', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Phone: ${request.contact!['owner_phone'] ?? 'N/A'}'),
                    Text('Address: ${request.contact!['address'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ),

          // The chat opened when the host accepted
          if (conversationId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => context.push('/conversation/$conversationId'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Open chat'),
              ),
            ),

          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                    side: BorderSide(color: context.colors.error),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: context.colors.surfaceLow,
      child: Icon(Icons.home, color: context.colors.outline),
    );
  }
}

// Requests whose cancel call is running (ignores a second tap meanwhile)
final _cancelsInFlight = <int>{};

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/errors/auth_exception.dart';
import '../auth/providers/auth_provider.dart';
import '../housing/models/housing_request.dart';

class RequestsTab extends ConsumerWidget {
  const RequestsTab({super.key});

  Future<void> _handleAction(BuildContext context, WidgetRef ref, HousingRequest req, String action) async {
    try {
      if (action == 'accept') {
        await ref.read(authRepoProvider).api.acceptRequest(req.id);
      } else {
        await ref.read(authRepoProvider).api.declineRequest(req.id);
      }
      
      // Refresh the list
      ref.invalidate(receivedRequestsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request $action successful!')),
        );
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(receivedRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: AppColors.outline),
                SizedBox(height: 16),
                Text('No requests yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('When someone asks for your room, it will appear here.', style: TextStyle(color: AppColors.outline)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(receivedRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final req = requests[index];
              return _RequestCard(
                request: req,
                onAccept: () => _handleAction(context, ref, req, 'accept'),
                onDecline: () => _handleAction(context, ref, req, 'decline'),
              );
            },
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final HousingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    bool isPending = request.status == 'pending';
    bool isAccepted = request.status == 'accepted';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.secondaryContainer,
                  child: Text(
                    request.senderName.isNotEmpty ? request.senderName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.senderName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Wants: ${request.listing.title}', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange.withValues(alpha: 0.1) : isAccepted ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isPending ? Colors.orange : isAccepted ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Message Body
          if (request.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
                child: Text('"${request.message}"', style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            ),

          // Contact info (Unlocked if accepted)
          if (isAccepted && request.contact != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_open, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Contact Unlocked', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Phone: ${request.contact!['sender_phone'] ?? 'N/A'}'),
                    Text('Address: ${request.contact!['address'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ),

          // Actions (Only show if pending)
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
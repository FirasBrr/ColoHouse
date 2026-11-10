import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/errors/auth_exception.dart';
import '../auth/providers/auth_provider.dart';
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Yes, Cancel')
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(authRepoProvider).api.cancelRequest(requestId);
      ref.invalidate(sentRequestsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled')),
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
    final requestsAsync = ref.watch(sentRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.outbox_outlined, size: 64, color: AppColors.outline),
                SizedBox(height: 16),
                Text('No sent requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('When you request a room, it will appear here.', style: TextStyle(color: AppColors.outline)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(sentRequestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final req = requests[index];
              return _SentRequestCard(
                request: req,
                onCancel: () => _cancelRequest(context, ref, req.id),
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
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
                      ? Image.network(request.listing.photo!, width: 50, height: 50, fit: BoxFit.cover)
                      : Container(width: 50, height: 50, color: AppColors.surfaceLow, child: const Icon(Icons.home)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.listing.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('To: ${request.ownerName}', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                    ],
                  ),
                ),
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
          
          if (isAccepted && request.contact != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
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
                        Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Request Accepted!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Phone: ${request.contact!['owner_phone'] ?? 'N/A'}'),
                    Text('Address: ${request.contact!['address'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ),

          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('Cancel Request'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
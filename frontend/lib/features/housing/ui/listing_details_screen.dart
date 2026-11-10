import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/errors/auth_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/listing.dart';

class ListingDetailsScreen extends ConsumerStatefulWidget {
  final int listingId;
  const ListingDetailsScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends ConsumerState<ListingDetailsScreen> {
  bool _sendingRequest = false;

  Future<void> _sendRequest(HousingListing listing) async {
    final TextEditingController msgController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send a message to ${listing.ownerName} to ask for this room.'),
            const SizedBox(height: 12),
            TextField(
              controller: msgController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Hi, I am interested...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _sendingRequest = true);
    try {
      await ref.read(authRepoProvider).api.sendRequest(listing.id, msgController.text.trim());
      ref.invalidate(listingDetailsProvider(listing.id)); // Refresh to show "PENDING"
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  Future<void> _deleteListing(HousingListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text('This will hide the listing from the search. You cannot undo this.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete')
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(authRepoProvider).api.deleteListing(listing.id);
      ref.invalidate(listingsProvider('')); 
      ref.invalidate(myListingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
        context.pop(); 
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingDetailsProvider(widget.listingId));
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (listing) {
          String coverUrl = listing.photos.isNotEmpty
              ? listing.photos.first.image
              : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800';

          List<ListingPhoto> galleryPhotos = listing.photos.length > 1
              ? listing.photos.sublist(1)
              : [];

          bool isOwner = currentUser?.id == listing.ownerId;
          bool canSendRequest = !isOwner && !listing.contactVisible && listing.myRequest == null;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: AppColors.primary,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    actions: [
                      if (isOwner)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.push('/listing/${listing.id}/edit', extra: listing);
                            } else if (value == 'delete') {
                              _deleteListing(listing);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit / Pause Listing')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete Listing', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceLow,
                          child: const Icon(Icons.home, size: 80, color: AppColors.outline),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${listing.rent} TND / month', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              if (isOwner) _StatusBadge(status: listing.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(listing.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Tag(icon: Icons.meeting_room_outlined, text: listing.roomType.toUpperCase()),
                              const SizedBox(width: 8),
                              _Tag(icon: Icons.location_city, text: listing.cityName),
                            ],
                          ),
                          const Divider(height: 40),
                          
                          const Text('About this place', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(listing.description, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.onSurfaceVariant)),
                          
                          if (galleryPhotos.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('Photo Gallery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: galleryPhotos.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      galleryPhotos[index].image,
                                      width: 160,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 160, height: 120, color: AppColors.surfaceLow,
                                        child: const Icon(Icons.broken_image, color: AppColors.outline),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          if (listing.rules.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('House Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(listing.rules, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.onSurfaceVariant)),
                          ],
                          
                          const SizedBox(height: 24),
                          const Text('Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(listing.latitude, listing.longitude),
                                  initialZoom: 14,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                ),
                                children: [
                                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.colohouse.app'),
                                  MarkerLayer(markers: [
                                    Marker(point: LatLng(listing.latitude, listing.longitude), width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.primary, size: 40)),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.surfaceLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 24, backgroundColor: AppColors.secondaryContainer, child: const Icon(Icons.person, color: AppColors.primaryDark)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(listing.ownerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      if (listing.isVerifiedOwner)
                                        const Row(
                                          children: [
                                            Icon(Icons.verified, size: 14, color: AppColors.primary),
                                            SizedBox(width: 4),
                                            Text('Verified Host', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (listing.contactVisible && listing.ownerPhone != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Text('Contact: ${listing.ownerPhone}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 200), 
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // BOTTOM BUTTONS
              if (canSendRequest)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surfaceLowest, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
                    child: SafeArea(
                      child: FilledButton.icon(
                        onPressed: _sendingRequest ? null : () => _sendRequest(listing),
                        icon: _sendingRequest ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                        label: Text(_sendingRequest ? 'Sending...' : 'Send Request'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ),
                )
              else if (!isOwner && listing.myRequest != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surfaceLowest, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
                    child: SafeArea(
                      child: FilledButton.icon(
                        onPressed: null, // Disabled
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          'Request ${listing.myRequest!.status.toUpperCase()}', 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: AppColors.surfaceLow,
                          disabledForegroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final color = isActive ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}
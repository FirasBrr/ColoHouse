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
  bool _isFavorite = false;

  Future<void> _sendRequest(HousingListing listing) async {
    final TextEditingController msgController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Application'),
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
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply Now')),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _sendingRequest = true);
    try {
      await ref.read(authRepoProvider).api.sendRequest(listing.id, msgController.text.trim());
      if (!mounted) return;
      // Refetch so my_request becomes the new pending request
      ref.invalidate(listingDetailsProvider(listing.id));
      ref.invalidate(sentRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent successfully!')));
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

          // Get the rest of the photos for the gallery
          List<ListingPhoto> galleryPhotos = listing.photos.length > 1
              ? listing.photos.sublist(1)
              : [];

          bool isOwner = currentUser?.id == listing.ownerId;
          // Only a pending or accepted request blocks a new one (backend rule)
          final requestStatus = listing.myRequest?.status;
          bool hasOpenRequest = requestStatus == 'pending' || requestStatus == 'accepted';
          bool canSendRequest = !isOwner && !listing.contactVisible && !hasOpenRequest;
          // Latest request was declined / cancelled: the student can apply again
          String? previousRequestNote = canSendRequest && requestStatus != null
              ? _previousRequestNote(requestStatus)
              : null;
          // The refetch after sending still shows the old my_request, keep the button busy
          bool isSending = _sendingRequest || listingAsync.isLoading;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // 1. Hero Image
                  SliverAppBar(
                    expandedHeight: 320,
                    pinned: true,
                    // Clear over the photo, solid once collapsed so the content doesn't show through
                    backgroundColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.scrolledUnder) ? AppColors.surface : Colors.transparent,
                    ),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    actions: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        child: IconButton(
                          icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: AppColors.primary),
                          onPressed: () => setState(() => _isFavorite = !_isFavorite),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isOwner)
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppColors.onSurface),
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
                        ),
                      const SizedBox(width: 8),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(coverUrl, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          if (listing.photos.isNotEmpty)
                            Positioned(
                              bottom: 16, right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('${listing.photos.length} photos', style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Details Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Location Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (listing.isVerifiedOwner) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(99)),
                                    child: const Text('VERIFIED HOST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Text(listing.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(listing.cityName, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant))),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(text: '${listing.rent} TND', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                                const TextSpan(text: ' / month', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Utilities included', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      if (listing.deposit > 0)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Refundable Deposit', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                                            Text('${listing.deposit} TND', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildSpecBadge(Icons.bedroom_parent, listing.roomType),
                                    _buildSpecBadge(Icons.calendar_today, 'Available ${listing.availableFrom}'),
                                    if (listing.distanceKm != null)
                                      _buildSpecBadge(Icons.explore, '${listing.distanceKm!.toStringAsFixed(1)} km away'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Description Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('About this place', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text(listing.description, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ===== PHOTO GALLERY SECTION (Added Back) =====
                          if (galleryPhotos.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // House Rules Card
                          if (listing.rules.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('House Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(listing.rules, style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Map Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Neighborhood', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Container(
                                  height: 160,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineVariant)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Host Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.secondaryContainer,
                                  child: const Icon(Icons.person, color: AppColors.primaryDark),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('Host: ${listing.ownerName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                          if (listing.isVerifiedOwner) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (listing.contactVisible && listing.ownerPhone != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                                    child: Text(listing.ownerPhone!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                              ],
                            ),
                          ),

                          // Room for the sticky bottom bar (taller when it shows the note)
                          SizedBox(height: previousRequestNote != null ? 150 : 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // 3. Sticky Bottom Action Bar
              if (canSendRequest)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest.withValues(alpha: 0.95),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
                    ),
                    // Bottom inset only, the status bar inset made the bar ~50px too tall
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (previousRequestNote != null) ...[
                            _buildPreviousRequestNote(requestStatus!, previousRequestNote),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(text: '${listing.rent} TND', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                        const TextSpan(text: ' / mo', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Text('Available ${listing.availableFrom}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: isSending ? null : () => _sendRequest(listing),
                                  icon: isSending
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Icon(previousRequestNote != null ? Icons.refresh : Icons.send, size: 18),
                                  label: Text(isSending
                                    ? 'Sending...'
                                    : previousRequestNote != null ? 'Apply Again' : 'Apply Now'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
                      top: false,
                      child: FilledButton.icon(
                        onPressed: null, 
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Request ${listing.myRequest!.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
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

  String _previousRequestNote(String status) {
    switch (status) {
      case 'declined':
        return 'Your previous request was declined by the host.';
      case 'cancelled':
        return 'You cancelled your previous request.';
      default:
        return 'Your previous request was $status.';
    }
  }

  Widget _buildPreviousRequestNote(String status, String note) {
    final isDeclined = status == 'declined';
    final color = isDeclined ? AppColors.error : AppColors.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDeclined ? AppColors.errorContainer : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isDeclined ? Icons.cancel_outlined : Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color))),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
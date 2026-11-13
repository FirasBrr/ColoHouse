import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/listing.dart';

// Map center when there is nothing else to show
const _tunis = LatLng(36.8065, 10.1815);

// Map of search results: one price marker per spot, tap a marker to see a small card.
// Coordinates are rounded to ~1 km by the backend until a request is accepted,
// so several listings can share a spot: they get one "+N" marker and swipeable cards.
class ListingsMapView extends StatefulWidget {
  final List<HousingListing> listings;
  final LatLng? fallbackCenter; // e.g. the chosen city center, used when no listing has a location
  final ValueChanged<HousingListing> onOpen;

  const ListingsMapView({
    super.key,
    required this.listings,
    required this.onOpen,
    this.fallbackCenter,
  });

  @override
  State<ListingsMapView> createState() => _ListingsMapViewState();
}

class _ListingsMapViewState extends State<ListingsMapView> {
  static const _fitPadding = EdgeInsets.fromLTRB(48, 72, 48, 140); // Room for the banners and the card

  final _mapController = MapController();
  bool _mapReady = false;
  LatLng? _selectedPoint;

  // HousingListing.fromJson turns missing coordinates into 0/0
  static bool _hasLocation(HousingListing l) => !(l.latitude == 0 && l.longitude == 0);

  static LatLng _pointOf(HousingListing l) => LatLng(l.latitude, l.longitude);

  // Located listings grouped by spot, cheapest first
  Map<LatLng, List<HousingListing>> get _groups {
    final groups = <LatLng, List<HousingListing>>{};
    for (final l in widget.listings.where(_hasLocation)) {
      groups.putIfAbsent(_pointOf(l), () => []).add(l);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.rent.compareTo(b.rent));
    }
    return groups;
  }

  LatLng get _emptyCenter => widget.fallbackCenter ?? _tunis;

  @override
  void didUpdateWidget(covariant ListingsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameResults = listEquals(
      oldWidget.listings.map((l) => l.id).toList(),
      widget.listings.map((l) => l.id).toList(),
    );
    if (!sameResults || oldWidget.fallbackCenter != widget.fallbackCenter) {
      _selectedPoint = null;
      // Move the camera after this frame (the map can't change while it is being built)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _fitCamera();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitCamera() {
    final points = _groups.keys.toList();
    if (points.length > 1) {
      _mapController.fitCamera(CameraFit.coordinates(coordinates: points, padding: _fitPadding, maxZoom: 15));
    } else if (points.length == 1) {
      _mapController.move(points.first, 14);
    } else {
      _mapController.move(_emptyCenter, 12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final points = groups.keys.toList();
    final missing = widget.listings.where((l) => !_hasLocation(l)).length;
    final selected = groups[_selectedPoint];

    // Draw the selected marker last so it stays on top
    final ordered = [
      ...points.where((p) => p != _selectedPoint),
      ...points.where((p) => p == _selectedPoint),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.length == 1 ? points.first : _emptyCenter,
            initialZoom: points.length == 1 ? 14 : 12,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(coordinates: points, padding: _fitPadding, maxZoom: 15)
                : null,
            onMapReady: () => _mapReady = true,
            onTap: (_, __) {
              if (_selectedPoint != null) setState(() => _selectedPoint = null);
            },
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.colohouse.app'),
            MarkerLayer(
              markers: [
                for (final p in ordered)
                  Marker(
                    point: p,
                    width: groups[p]!.length > 1 ? 120 : 96,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPoint = p),
                      child: _PriceMarker(
                        rent: groups[p]!.first.rent,
                        more: groups[p]!.length - 1,
                        selected: p == _selectedPoint,
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
          ],
        ),

        // Info banners
        if (widget.listings.isEmpty)
          const _MapBanner(icon: Icons.search_off, text: 'No listings match your search.')
        else if (missing > 0)
          _MapBanner(
            icon: Icons.info_outline,
            text: missing == 1 ? '1 listing has no location and is only in the list.' : '$missing listings have no location and are only in the list.',
          ),

        // Selected listing card
        if (selected != null && selected.length == 1)
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: _MapListingCard(
              listing: selected.first,
              onTap: () => widget.onOpen(selected.first),
              onClose: () => setState(() => _selectedPoint = null),
            ),
          )
        // Several listings at this spot: swipe between their cards
        else if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: _MapListingPager(
              key: ValueKey(_selectedPoint),
              listings: selected,
              onOpen: widget.onOpen,
              onClose: () => setState(() => _selectedPoint = null),
            ),
          ),
      ],
    );
  }
}

class _PriceMarker extends StatelessWidget {
  final int rent;
  final int more; // Other listings at the same spot
  final bool selected;
  const _PriceMarker({required this.rent, required this.more, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            more > 0 ? '$rent TND +$more' : '$rent TND',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MapBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapListingCard extends StatelessWidget {
  final HousingListing listing;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const _MapListingCard({required this.listing, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final photo = listing.photos.isNotEmpty ? listing.photos.first.image : null;
    final placeholder = Container(
      color: AppColors.surfaceLow,
      child: const Icon(Icons.home, size: 32, color: AppColors.outline),
    );

    return Material(
      color: AppColors.surfaceLowest,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: photo == null
                      ? placeholder
                      : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing.distanceKm == null
                                ? listing.cityName
                                : '${listing.cityName} · ${listing.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 12, color: AppColors.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '${listing.rent} TND', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          const TextSpan(text: ' / month', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.outline),
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Cards for several listings that share one marker, with the next card peeking in
class _MapListingPager extends StatefulWidget {
  final List<HousingListing> listings;
  final ValueChanged<HousingListing> onOpen;
  final VoidCallback onClose;
  const _MapListingPager({super.key, required this.listings, required this.onOpen, required this.onClose});

  @override
  State<_MapListingPager> createState() => _MapListingPagerState();
}

class _MapListingPagerState extends State<_MapListingPager> {
  final _pageController = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.listings.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(
            '$count places at this spot · ${_page + 1}/$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
          ),
        ),
        SizedBox(
          height: 124, // Card height plus room for its shadow
          child: PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: _MapListingCard(
                  listing: widget.listings[i],
                  onTap: () => widget.onOpen(widget.listings[i]),
                  onClose: widget.onClose,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

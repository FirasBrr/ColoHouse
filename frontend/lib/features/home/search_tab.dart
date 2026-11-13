import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../housing/models/listing_filters.dart';
import '../housing/ui/widgets/listing_card.dart';
import '../housing/ui/widgets/listing_filters_sheet.dart';
import '../housing/ui/widgets/listings_map_view.dart';
import 'widgets/home_app_bar.dart'; // Imported for the consistent header

class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final _searchController = TextEditingController();
  ListingFilters _filters = const ListingFilters(); // Text query + Sprint 2 filters
  int _selectedTab = 0; // 0 = Rooms, 1 = Roommates
  bool _showMap = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    // Also take the text typed but not submitted yet, so both are applied together
    final result = await showListingFiltersSheet(
      context,
      _filters.copyWith(query: _searchController.text.trim()),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  Future<void> _refresh() {
    // Unfiltered searches come from listingsProvider, refresh it too
    ref.invalidate(listingsProvider(_filters.query.trim()));
    return ref.refresh(searchListingsProvider(_filters).future);
  }

  // Center of the chosen city, used by the map when no result has a location
  LatLng? _cityCenter() {
    final cityId = _filters.cityId;
    if (cityId == null) return null;
    final cities = ref.watch(cityListProvider).valueOrNull ?? [];
    final city = cities.where((c) => c.id == cityId).firstOrNull;
    if (city == null || (city.latitude == 0 && city.longitude == 0)) return null;
    return LatLng(city.latitude, city.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(searchListingsProvider(_filters));
    final user = ref.watch(authProvider).user;
    final activeFilters = _filters.activeCount;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Replaced custom header with HomeAppBar for consistency
          HomeAppBar(user: user),

          // Search Bar & Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // Adjusted padding
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => setState(() => _filters = _filters.copyWith(query: v.trim())),
                      decoration: InputDecoration(
                        hintText: 'Search rooms, areas...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _filters.query.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                                _searchController.clear();
                                setState(() => _filters = _filters.copyWith(query: ''));
                              })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterButton(activeFilters),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Segmented Tabs (Rooms vs Roommates)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  _buildTabButton('Rooms & Homes', 0),
                  _buildTabButton('Roommates', 1),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Results count + List / Map toggle
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listingsAsync.hasValue
                          ? '${listingsAsync.value!.length} ${listingsAsync.value!.length == 1 ? 'place' : 'places'} found'
                          : listingsAsync.isLoading ? 'Searching...' : '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  if (activeFilters > 0)
                    TextButton(
                      onPressed: () => setState(() => _filters = _filters.cleared()),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: AppColors.primary),
                      child: const Text('Clear filters', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(width: 4),
                  _buildViewToggle(),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? listingsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (listings) {
                      if (_showMap) {
                        return ListingsMapView(
                          listings: listings,
                          fallbackCenter: _cityCenter(),
                          onOpen: (listing) => context.push('/listing/${listing.id}'),
                        );
                      }
                      if (listings.isEmpty) {
                        return _buildEmptyState(activeFilters > 0);
                      }
                      return RefreshIndicator(
                        onRefresh: _refresh,
                        color: AppColors.primary,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: listings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            final listing = listings[index];
                            return ListingCard(
                              listing: listing,
                              onTap: () => context.push('/listing/${listing.id}'),
                            );
                          },
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('Roommate matching coming soon!', style: TextStyle(color: AppColors.outline)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(int activeFilters) {
    final active = activeFilters > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: IconButton(
            icon: Icon(Icons.tune, color: active ? Colors.white : AppColors.primary),
            tooltip: 'Filters',
            onPressed: _openFilters,
          ),
        ),
        // Active filter count
        if (active)
          Positioned(
            top: -6,
            right: -6,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.surfaceLowest, width: 2),
                ),
                child: Text(
                  '$activeFilters',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(Icons.view_agenda_outlined, 'List', !_showMap, () => setState(() => _showMap = false)),
          _buildToggleButton(Icons.map_outlined, 'Map', _showMap, () => setState(() => _showMap = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasFilters) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'No listings match these filters.' : 'No listings found.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _filters = _filters.cleared()),
                child: const Text('Clear filters', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../housing/ui/widgets/listing_card.dart';
import 'widgets/home_app_bar.dart'; // Imported for the consistent header

class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final _searchController = TextEditingController();
  String _query = '';
  int _selectedTab = 0; // 0 = Rooms, 1 = Roommates

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(listingsProvider(_query));
    final user = ref.watch(authProvider).user;

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
                      onSubmitted: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search rooms, areas...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _query.isNotEmpty 
                            ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              }) 
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: AppColors.primary),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advanced filters coming soon!'))),
                  ),
                ),
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

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? listingsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (listings) {
                      if (listings.isEmpty) {
                        return const Center(child: Text('No listings found.'));
                      }
                      return ListView.separated(
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
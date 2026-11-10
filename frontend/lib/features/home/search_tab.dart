import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; 
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../housing/ui/widgets/listing_card.dart';

class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watches the provider with the current search query
    final listingsAsync = ref.watch(listingsProvider(_query));

    return SafeArea(
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by title, description...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Listings Feed
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error loading listings: $e',
                    style: const TextStyle(color: AppColors.error)),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_work_outlined, size: 48, color: AppColors.outline),
                        SizedBox(height: 12),
                        Text('No listings found.', style: TextStyle(color: AppColors.outline)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(listingsProvider(_query));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
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
            ),
          ),
        ],
      ),
    );
  }
}
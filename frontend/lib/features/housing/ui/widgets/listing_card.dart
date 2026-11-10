import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/listing.dart';

class ListingCard extends StatelessWidget {
  final HousingListing listing;
  final VoidCallback onTap;

  const ListingCard({super.key, required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String imageUrl = listing.photos.isNotEmpty
        ? listing.photos.first.image
        : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=500'; // Fallback

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: AppColors.surfaceLow,
                  child: const Icon(Icons.home, size: 40, color: AppColors.outline),
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${listing.rent} TND / month',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (listing.distanceKm != null)
                        Text(
                          '${listing.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    listing.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.roomType.toUpperCase()} • ${listing.cityName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
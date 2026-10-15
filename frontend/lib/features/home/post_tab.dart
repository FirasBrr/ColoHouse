import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PostTab extends StatelessWidget {
  const PostTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_home_outlined,
                    size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'Post a listing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Publish a room, apartment, or shared space. Coming soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.outline,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
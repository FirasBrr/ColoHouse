import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class VerificationBanner extends StatelessWidget {
  final VoidCallback onTap;

  const VerificationBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.tertiaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.tertiaryFixed,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.colors.tertiaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline,
                size: 17, color: context.colors.tertiary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your profile to get verified and unlock all features.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: context.colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              'Fix →',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

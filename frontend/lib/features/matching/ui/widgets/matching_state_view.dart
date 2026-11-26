import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Centered icon + title + sentence + buttons (empty, error and unavailable states).
class MatchingStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? detail; // small grey line, e.g. the server's error message
  final List<Widget> actions;
  final bool isError;

  const MatchingStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.actions = const [],
    this.isError = false,
  });

  // The theme's FilledButton is full width; state buttons stay pill-sized
  static final buttonStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 24),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isError ? context.colors.errorContainer : context.colors.surfaceLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: isError ? context.colors.error : context.colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: context.colors.outline),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: context.colors.outline),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

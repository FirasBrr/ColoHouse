import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Empty list: icon + title + sentence.
class ChatEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const ChatEmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: context.colors.surfaceLow, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: context.colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error message + Retry button.
class ChatErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ChatErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: context.colors.errorContainer, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_outlined, size: 38, color: context.colors.error),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a centered state (empty list) be pulled down to refresh.
class RefreshableFill extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const RefreshableFill({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.colors.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

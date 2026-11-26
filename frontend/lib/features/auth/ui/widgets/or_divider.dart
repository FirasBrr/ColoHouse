import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// "──── or ────" separator between the email form and the Google button.
class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, this.label = 'or'});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: context.colors.outlineVariant, thickness: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 12, color: context.colors.onSurfaceVariant),
          ),
        ),
        line,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Red error box shown above the auth forms; fades/resizes in and out.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(message),
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: context.colors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(message!,
                            style: TextStyle(
                                color: context.colors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

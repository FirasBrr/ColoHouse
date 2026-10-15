import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _notifyRequests = true;
  bool _notifyMessages = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _pushEnabled = user.pushEnabled;
      _notifyRequests = user.notifyRequests;
      _notifyMessages = user.notifyMessages;
    }
  }

  Future<void> _update(Map<String, dynamic> changes) async {
    try {
      await ref.read(authRepoProvider).updateProfile(changes);
      await ref.read(authProvider.notifier).refreshUser();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account and all your data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authRepoProvider).deleteAccount();
      await ref.read(authProvider.notifier).logout();
      // Router will redirect to /login automatically
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            // ===== Notifications =====
            const _SectionHeader(
              icon: Icons.notifications_active_outlined,
              label: 'Notifications',
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable push notifications'),
                    subtitle: const Text(
                      'Alerts for requests and messages',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _pushEnabled,
                    onChanged: (v) {
                      setState(() => _pushEnabled = v);
                      _update({'push_enabled': v});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Housing request updates'),
                    subtitle: const Text(
                      'Acceptances, declines, new requests',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notifyRequests,
                    onChanged: (v) {
                      setState(() => _notifyRequests = v);
                      _update({'notify_requests': v});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('New messages'),
                    subtitle: const Text(
                      'Direct chat notifications',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _notifyMessages,
                    onChanged: (v) {
                      setState(() => _notifyMessages = v);
                      _update({'notify_messages': v});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ===== Privacy card =====
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryContainer,
                    ),
                    child: const Icon(Icons.verified_user,
                        size: 18, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy First',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Your contact details stay private until you accept a connection.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ===== Danger zone =====
            const _SectionHeader(
              icon: Icons.warning_amber_outlined,
              label: 'Danger Zone',
              color: AppColors.error,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delete Account',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Removing your account will erase all your data. This action is permanent.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _deleting ? null : _deleteAccount,
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.error),
                            )
                          : const Icon(Icons.delete_outline, size: 20),
                      label: Text(_deleting
                          ? 'Deleting…'
                          : 'Delete my account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ===== Footer =====
            const Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apartment,
                          size: 16, color: AppColors.outline),
                      SizedBox(width: 6),
                      Text('Colohouse',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.outline)),
                    ],
                  ),
                  SizedBox(height: 4),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'auth_field.dart';
import 'auth_validators.dart';

/// Asks for the email and sends a Firebase password reset link.
/// Returns the email when the link was sent, null if closed.
Future<String?> showForgotPasswordDialog(BuildContext context,
    {String initialEmail = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(initialEmail: initialEmail),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final email = _email.text.trim();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) Navigator.pop(context, email);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the email. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'This email address is not valid.';
      case 'user-not-found':
        return 'No account uses this email.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Could not send the email. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.surfaceLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.lock_reset, color: context.colors.primary, size: 32),
      title: const Text('Reset your password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enter your account email and we'll send you a link to choose a new password.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              onFieldSubmitted: (_) {
                if (!_sending) _send();
              },
              enabled: !_sending,
              validator: AuthValidators.email,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}

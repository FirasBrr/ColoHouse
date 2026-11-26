import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/firebase_auth_service.dart';
import '../providers/auth_provider.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_validators.dart';
import 'widgets/forgot_password_dialog.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/or_divider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  bool get _busy => _loading || _googleLoading;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // On success the router redirects by itself (home, or profile setup for a new account)
  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(
            _email.text.trim(),
            _password.text,
          );
    } on EmailNotVerifiedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify your email first')),
      );
      context.go('/verify-email');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _googleLoading = true;
    });
    try {
      await ref.read(authProvider.notifier).loginWithGoogle();
    } on SignInCancelled {
      // Picker closed: nothing to show
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showForgotPasswordDialog(
      context,
      initialEmail: _email.text.trim(),
    );
    if (email == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'If an account exists for $email, a reset link is on its way.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Header icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primary,
                ),
                child: const Icon(Icons.home_work_outlined,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to continue your housing search',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              // Trust pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.surfaceLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 14, color: context.colors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'TRUSTED HOUSING PLATFORM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: context.colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Form card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surfaceLowest,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthErrorBanner(message: _error),
                        AuthField(
                          controller: _email,
                          label: 'Email',
                          hint: 'you@example.com',
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !_busy,
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 16),
                        AuthField(
                          controller: _password,
                          label: 'Password',
                          hint: '••••••••',
                          prefixIcon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          enabled: !_busy,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _forgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Forgot password?',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Log in'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        const OrDivider(),
                        const SizedBox(height: 20),
                        GoogleSignInButton(
                          onPressed: _busy ? null : _google,
                          loading: _googleLoading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account?",
                      style: TextStyle(color: context.colors.onSurfaceVariant)),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/register'),
                    child: const Text('Register',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.surfaceLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: context.colors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Your Privacy & Identity Protected',
                      style: TextStyle(
                          fontSize: 11, color: context.colors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

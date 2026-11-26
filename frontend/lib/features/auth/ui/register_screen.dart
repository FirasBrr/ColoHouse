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
import 'widgets/google_sign_in_button.dart';
import 'widgets/or_divider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  bool get _busy => _loading || _googleLoading;

  @override
  void initState() {
    super.initState();
    // Redraw the strength meter while typing
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 1 = weak (fails the rule), 2 = fair, 3 = strong
  int _strength(String pwd) {
    if (AuthValidators.newPassword(pwd) != null) return 1;
    var extras = 0;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) {
      extras++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) extras++;
    if (pwd.length >= 12) extras++;
    return extras >= 2 ? 3 : 2;
  }

  // Creates the Firebase account + sends the verification email (not logged in yet)
  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).register(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/verify-email?sent=1');
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

  @override
  Widget build(BuildContext context) {
    final strength = _strength(_password.text);
    final strengthColor = switch (strength) {
      1 => context.colors.error,
      2 => context.colors.tertiary,
      _ => context.colors.primary,
    };
    final strengthLabel = switch (strength) {
      1 => 'Weak',
      2 => 'Fair',
      _ => 'Strong',
    };

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: const Text('Create account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header pill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home_work_outlined,
                              size: 13, color: context.colors.primaryDark),
                          const SizedBox(width: 6),
                          Text('SHARED LIVING, SIMPLIFIED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: context.colors.primaryDark,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Join Colohouse',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: context.colors.onSurface)),
                  const SizedBox(height: 4),
                  Text('Find housing and roommates that fit you',
                      style:
                          TextStyle(color: context.colors.onSurfaceVariant)),
                  const SizedBox(height: 20),

                  AuthErrorBanner(message: _error),

                  // Row: First + Last
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AuthField(
                          controller: _firstName,
                          label: 'First name',
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                          validator: (v) =>
                              AuthValidators.name(v, 'First name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AuthField(
                          controller: _lastName,
                          label: 'Last name',
                          enabled: !_busy,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.familyName],
                          validator: (v) =>
                              AuthValidators.name(v, 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  AuthField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: 16),

                  AuthField(
                    controller: _password,
                    label: 'Password',
                    hint: '8+ characters, a letter and a digit',
                    prefixIcon: Icons.lock_outline,
                    obscure: true,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.newPassword,
                  ),

                  // Password strength meter
                  if (_password.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(3, (i) {
                          final active = i < strength;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: active
                                      ? strengthColor
                                      : context.colors.surfaceLow,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 48,
                          child: Text(strengthLabel,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: strengthColor)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  AuthField(
                    controller: _confirm,
                    label: 'Confirm password',
                    hint: 'Re-enter password',
                    prefixIcon: Icons.lock_reset,
                    obscure: true,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _password.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            color: context.colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Verify your email to get started',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                "We'll send you a link to confirm your address, then you can find roommates and listings.",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              Text('Create account'),
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
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?',
                          style: TextStyle(
                              color: context.colors.onSurfaceVariant)),
                      TextButton(
                        onPressed:
                            _busy ? null : () => context.go('/login'),
                        child: const Text('Log in',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'By registering, you agree to Colohouse Terms of Service and Community Guidelines.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: context.colors.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

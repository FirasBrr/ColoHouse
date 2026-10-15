import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'widgets/auth_field.dart';

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
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// 0 = weak, 1 = fair, 2 = good, 3 = strong
  int _strength(String pwd) {
    if (pwd.length < 6) return 0;
    var s = 0;
    if (pwd.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd)) {
      s++;
    }
    if (RegExp(r'[0-9]').hasMatch(pwd)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) s++;
    return s.clamp(0, 3);
  }

  Future<void> _submit() async {
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
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength(_password.text);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Create account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_work_outlined,
                          size: 13, color: AppColors.primaryDark),
                      SizedBox(width: 6),
                      Text('SHARED LIVING, SIMPLIFIED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.primaryDark,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Join Colohouse',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Find housing and roommates that fit you',
                    style:
                        TextStyle(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Row: First + Last
                Row(
                  children: [
                    Expanded(
                      child: AuthField(
                        controller: _firstName,
                        label: 'First name',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthField(
                        controller: _lastName,
                        label: 'Last name',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email required';
                    }
                    if (!EmailValidator.validate(v.trim())) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _password,
                  label: 'Password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password required';
                    }
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),

                // Password strength meter
                if (_password.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(3, (i) {
                      final active = i < strength;
                      return Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(right: i < 2 ? 6 : 0),
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? (strength <= 1
                                      ? Colors.red
                                      : strength == 2
                                          ? Colors.orange
                                          : AppColors.primary)
                                  : AppColors.surfaceLow,
                              borderRadius:
                                  BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 16),

                AuthField(
                  controller: _confirm,
                  label: 'Confirm password',
                  hint: 'Re-enter password',
                  prefixIcon: Icons.lock_reset,
                  obscure: true,
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),

                // Info card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.key_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Instant Access & Roommate Matching',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            SizedBox(height: 2),
                            Text(
                              'Get matched with compatible roommates and unlock housing listings in minutes.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _loading ? null : _submit,
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
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant)),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.go('/login'),
                      child: const Text('Log in',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'By registering, you agree to Colohouse Terms of Service and Community Guidelines.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
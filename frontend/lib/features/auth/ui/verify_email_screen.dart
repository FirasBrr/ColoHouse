import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/auth_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// "Check your inbox" screen shown after an email/password sign-up, or when an unverified account logs in.
/// Opened with ?sent=1 right after sign-up: the resend button then starts with its cooldown.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  static const _cooldownSeconds = 30;

  bool _checking = false;
  bool _resending = false;
  bool _leaving = false;
  bool _visible = false;
  bool _readArgs = false;
  int _cooldown = 0;
  Timer? _timer;

  bool get _busy => _checking || _resending || _leaving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fade the content in after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArgs) return;
    _readArgs = true;
    // The email was just sent by the sign-up
    if (GoRouterState.of(context).uri.queryParameters['sent'] == '1') {
      _cooldown = _cooldownSeconds;
      _runTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Back from the mail app: check silently, the router moves on if it is verified
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _startCooldown() {
    setState(() => _cooldown = _cooldownSeconds);
    _runTimer();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.colors.error : null,
      ),
    );
  }

  // true -> the router redirects by itself (home, or profile setup for a new account)
  Future<void> _check({bool silent = false}) async {
    if (_busy) return;
    setState(() => _checking = true);
    try {
      final verified =
          await ref.read(authProvider.notifier).completeEmailVerification();
      if (!verified && !silent && mounted) {
        _snack(
            'Your email is not verified yet. Click the link in the email.');
      }
    } on AuthException catch (e) {
      if (!silent && mounted) _snack(e.message, error: true);
    } catch (_) {
      if (!silent && mounted) {
        _snack('Something went wrong. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendVerificationEmail();
      if (!mounted) return;
      _snack('A new verification email is on its way.');
      _startCooldown();
    } on AuthException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (_) {
      if (mounted) {
        _snack('Could not send the email. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    if (_busy) return;
    setState(() => _leaving = true);
    try {
      await ref.read(authProvider.notifier).cancelEmailVerification();
    } catch (_) {
      // Signed out locally anyway
    }
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(firebaseAuthServiceProvider).email;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _MailIllustration()),
                  const SizedBox(height: 24),
                  Text(
                    'Check your inbox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: 'We sent a verification link to\n',
                      children: [
                        TextSpan(
                          text: email ?? 'your email address',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),

                  // Steps card
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
                    child: const Column(
                      children: [
                        _Step(
                          number: 1,
                          text:
                              'Open the email from Colohouse (check your spam folder too).',
                        ),
                        SizedBox(height: 14),
                        _Step(
                          number: 2,
                          text: 'Tap the verification link inside.',
                        ),
                        SizedBox(height: 14),
                        _Step(
                          number: 3,
                          text: "Come back here and tap \"I've verified my email\".",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  FilledButton(
                    onPressed: _busy ? null : () => _check(),
                    child: _checking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 8),
                              Text("I've verified my email"),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  _ResendButton(
                    cooldown: _cooldown,
                    total: _cooldownSeconds,
                    loading: _resending,
                    onPressed: (_busy || _cooldown > 0) ? null : _resend,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _useAnotherAccount,
                      icon: _leaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: context.colors.primary),
                            )
                          : const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Use another account',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
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

// Envelope in two soft circles, pops in with a small bounce
class _MailIllustration extends StatelessWidget {
  const _MailIllustration();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.secondaryContainer.withValues(alpha: 0.5),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.primary,
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.mark_email_unread_outlined,
              color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.secondaryContainer,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13, color: context.colors.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

// Outlined button; during the cooldown it shows the countdown and fills up like a progress bar
class _ResendButton extends StatelessWidget {
  final int cooldown;
  final int total;
  final bool loading;
  final VoidCallback? onPressed;

  const _ResendButton({
    required this.cooldown,
    required this.total,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = cooldown > 0;
    return SizedBox(
      height: 52,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Countdown progress behind the label
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(seconds: 1),
                widthFactor: waiting ? 1 - cooldown / total : 0,
                heightFactor: 1,
                child: ColoredBox(
                  color: context.colors.secondaryContainer
                      .withValues(alpha: waiting ? 0.45 : 0),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.primary,
                disabledForegroundColor: context.colors.onSurfaceVariant,
                side: BorderSide(color: context.colors.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: context.colors.primary),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(waiting ? Icons.timer_outlined : Icons.refresh,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(waiting
                            ? 'Resend email in ${cooldown}s'
                            : 'Resend email'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

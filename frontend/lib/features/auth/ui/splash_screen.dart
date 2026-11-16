import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Theme is cached here because dispose() can't look it up anymore
  late AppPalette _colors;
  late bool _isDark;

  // Was initState: the theme can't be read there (and may change once the saved mode loads)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colors = context.colors;
    _isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _colors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: context.colors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.primary,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full-bleed background color
              Container(color: context.colors.primary),

              // Decorative top-left circle
              Positioned(
                top: -120,
                left: -120,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.secondaryContainer
                        .withValues(alpha: 0.10),
                  ),
                ),
              ),

              // Decorative bottom-right circle
              Positioned(
                bottom: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),

              // Content, centered vertically, safe-area aware
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo circle
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_work_outlined,
                        size: 48,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App name
                    const Text(
                      'Colohouse',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Find your next home',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Spinner
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom tagline
                    Text(
                      'SHARED LIVING SIMPLIFIED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Reset overlay style when leaving splash
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: _colors.surfaceLowest,
        systemNavigationBarIconBrightness:
            _isDark ? Brightness.light : Brightness.dark,
      ),
    );
    super.dispose();
  }
}
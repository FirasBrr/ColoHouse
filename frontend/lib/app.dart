import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ColohouseApp extends ConsumerWidget {
  const ColohouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Colohouse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // No Android 12+ stretch effect when a list is pulled past its end (it squashed the content)
      scrollBehavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      routerConfig: router,
    );
  }
}
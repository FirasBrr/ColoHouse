import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  // Kept apart from the tokens so logging out doesn't reset the theme
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kThemeMode = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.light) { // Default is light
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _kThemeMode);
    if (saved == 'dark' && mounted) state = ThemeMode.dark;
  }

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _storage.write(key: _kThemeMode, value: state == ThemeMode.dark ? 'dark' : 'light');
  }
}

// The provider that the app will watch
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

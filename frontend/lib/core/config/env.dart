class Env {
  // Android emulator reaches the host at 10.0.2.2. A physical device can use
  // 127.0.0.1 when adb reverse forwards port 8000 over USB.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}

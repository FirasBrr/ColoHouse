import '../../../core/storage/secure_storage.dart';
import 'auth_api.dart';
import '../models/user.dart';
import '../../profile/models/roommate_preferences.dart';

class AuthRepository {
  final AuthApi api;
  final SecureStorage storage;

  AuthRepository({required this.api, required this.storage});

  Future<User> registerAndLogin({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await api.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    return login(email: email, password: password);
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final tokens = await api.login(email: email, password: password);
    await storage.saveTokens(
      access: tokens['access']!,
      refresh: tokens['refresh']!,
    );
    return await api.me();
  }

  Future<User?> tryRestoreSession() async {
    final access = await storage.accessToken;
    if (access == null) return null;

    try {
      return await api.me();
    } catch (_) {
      final refresh = await storage.refreshToken;
      if (refresh == null) {
        await storage.clear();
        return null;
      }
      try {
        final newAccess = await api.refresh(refresh);
        await storage.saveTokens(access: newAccess, refresh: refresh);
        return await api.me();
      } catch (_) {
        await storage.clear();
        return null;
      }
    }
  }

  Future<void> logout() async {
    await storage.clear();
  }
  Future<User> updateProfile(Map<String, dynamic> changes) async {
  return api.updateProfile(changes);
}

Future<void> deleteAccount() => api.deleteAccount();

Future<RoommatePreferences> getPreferences() => api.getPreferences();

Future<RoommatePreferences> updatePreferences(
        Map<String, dynamic> changes) =>
    api.updatePreferences(changes);

Future<List<City>> listCities() => api.listCities();
}
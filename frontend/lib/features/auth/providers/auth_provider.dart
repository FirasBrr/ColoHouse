import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';
import '../../profile/models/roommate_preferences.dart';  
// --- dependency injection ---
final storageProvider = Provider<SecureStorage>((_) => SecureStorage());

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref.read(storageProvider));
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.read(dioClientProvider).dio);
});

final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.read(authApiProvider),
    storage: ref.read(storageProvider),
  );
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  const AuthState({required this.status, this.user});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repo;

  AuthNotifier(this.repo) : super(const AuthState(status: AuthStatus.unknown)) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = await repo.tryRestoreSession();
    state = user == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> login(String email, String password) async {
    final user = await repo.login(email: email, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final user = await repo.registerAndLogin(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
  Future<void> refreshUser() async {
  try {
    final user = await repo.api.me();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  } catch (_) {
  }
}
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepoProvider));
});
final cityListProvider = FutureProvider<List<City>>((ref) async {
  return ref.read(authRepoProvider).listCities();
});

final preferencesProvider = FutureProvider<RoommatePreferences>((ref) async {
  return ref.read(authRepoProvider).getPreferences();
});
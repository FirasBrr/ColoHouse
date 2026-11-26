import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../data/firebase_auth_service.dart';
import '../models/user.dart';
import '../../profile/models/roommate_preferences.dart';  
import '../../housing/models/listing.dart';
import '../../housing/models/housing_request.dart';
import '../../housing/models/listing_filters.dart';

// --- dependency injection ---
final storageProvider = Provider<SecureStorage>((_) => SecureStorage());

// Explicit type: the callback below makes the providers reference each other
final Provider<DioClient> dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.read(storageProvider),
    // Read lazily: authProvider itself depends on this provider
    onSessionExpired: () => ref.read(authProvider.notifier).sessionExpired(),
  );
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

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((_) => FirebaseAuthService());

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  // The account was just created by this login: the router opens the profile setup
  final bool isNewAccount;
  const AuthState({required this.status, this.user, this.isNewAccount = false});
}

/// Login = FirebaseAuth (email/password or Google) proves who the user is, then the Firebase
/// ID token is exchanged for our JWT pair (POST /api/auth/firebase/), used by every API call.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository repo;
  final FirebaseAuthService firebase;
  // Stops this phone's pushes. Set by the push service when it starts (it depends on this
  // notifier, not the other way round). notifyServer: false once the account is already deleted.
  Future<void> Function({bool notifyServer})? beforeLogout;

  AuthNotifier(this.repo, this.firebase)
      : super(const AuthState(status: AuthStatus.unknown)) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = await repo.tryRestoreSession();
    state = user == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Email/password login. Throws [EmailNotVerifiedException] when the email is not verified yet
  /// (show the verify-email screen), [AuthException] otherwise.
  Future<void> login(String email, String password) async {
    final idToken = await firebase.signInWithEmail(email, password);
    // Signed up on this phone but verified the email elsewhere: the account is created now
    final (firstName, lastName) = await repo.storage.pendingNamesFor(email);
    await _finishLoginOrSignOut(idToken, firstName: firstName, lastName: lastName);
  }

  /// Email/password sign-up: creates the Firebase account and sends the verification email.
  /// The user is NOT logged in yet: show the verify-email screen, then [completeEmailVerification].
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    // Saved first, with the email: whichever way the sign-up finishes, the names are used
    await repo.storage.savePendingNames(email, firstName.trim(), lastName.trim());
    try {
      await firebase.signUpWithEmail(email, password, displayName: '${firstName.trim()} ${lastName.trim()}'.trim());
    } catch (_) {
      await repo.storage.clearPendingNames();
      rethrow;
    }
  }

  Future<void> resendVerificationEmail() => firebase.resendVerificationEmail();

  /// "I verified my email" button. Returns false if the email is still not verified.
  Future<bool> completeEmailVerification() async {
    final idToken = await firebase.verifiedIdToken();
    if (idToken == null) return false;
    final (firstName, lastName) = await repo.storage.pendingNamesFor(firebase.email);
    await _finishLogin(idToken, firstName: firstName, lastName: lastName);
    return true;
  }

  /// "Use another account" on the verify-email screen.
  Future<void> cancelEmailVerification() async {
    await repo.storage.clearPendingNames();
    await firebase.signOut();
  }

  /// Google button. Throws [SignInCancelled] if the user closed the account picker.
  Future<void> loginWithGoogle() async {
    final idToken = await firebase.signInWithGoogle();
    await _finishLoginOrSignOut(idToken);
  }

  /// If the backend refuses the login (or is unreachable), also sign out of Firebase so the app
  /// never stays half logged in. Not used after email verification: there the Firebase session
  /// must survive so the user can just press "I've verified my email" again.
  Future<void> _finishLoginOrSignOut(String idToken, {String? firstName, String? lastName}) async {
    try {
      await _finishLogin(idToken, firstName: firstName, lastName: lastName);
    } catch (_) {
      await firebase.signOut();
      rethrow;
    }
  }

  Future<void> _finishLogin(String idToken, {String? firstName, String? lastName}) async {
    final ({User user, bool created}) result;
    try {
      result = await repo.loginWithFirebase(idToken, firstName: firstName, lastName: lastName);
    } catch (_) {
      // Tokens may be saved while loading the profile failed: never keep a half session
      await repo.storage.clear();
      rethrow;
    }
    await repo.storage.clearPendingNames();
    var user = result.user;
    // Pushes and match explanations are written in this language
    if (user.language != Env.language) {
      try {
        user = await repo.updateProfile({'language': Env.language});
      } catch (_) {}
    }
    state = AuthState(status: AuthStatus.authenticated, user: user, isNewAccount: result.created);
  }

  Future<void> logout() async {
    try {
      await beforeLogout?.call(notifyServer: true);
    } catch (_) {}
    await firebase.signOut();
    await repo.storage.clearPendingNames();
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Deletes the account on the server first (throws [AuthException] if it fails: nothing else
  /// changes then), then cleans up the phone. The server also deletes the Firebase login.
  Future<void> deleteAccount() async {
    await repo.deleteAccount();
    try {
      // The server already forgot this phone with the account: local clean-up only
      await beforeLogout?.call(notifyServer: false);
    } catch (_) {}
    await firebase.deleteFirebaseUser();
    await firebase.signOut();
    await repo.storage.clearPendingNames();
    await repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // The refresh token was rejected (tokens already cleared by the dio client)
  void sessionExpired() {
    if (!mounted) return;
    firebase.signOut();
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

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepoProvider),
    ref.read(firebaseAuthServiceProvider),
  );
});
final cityListProvider = FutureProvider<List<City>>((ref) async {
  return ref.read(authRepoProvider).listCities();
});

final preferencesProvider = FutureProvider<RoommatePreferences>((ref) async {
  return ref.read(authRepoProvider).getPreferences();
});

final listingsProvider = FutureProvider.autoDispose.family<List<HousingListing>, String>((ref, query) async {
  return ref.read(authRepoProvider).getListings(query: query);
});

// Search tab (text + filters). Without filters it reuses listingsProvider, so the screens
// that invalidate listingsProvider('') after posting/editing also refresh the search results.
final searchListingsProvider = FutureProvider.autoDispose.family<List<HousingListing>, ListingFilters>((ref, filters) async {
  if (!filters.hasFilters) return ref.watch(listingsProvider(filters.query.trim()).future);
  return ref.read(authRepoProvider).getListings(filters: filters);
});

final listingDetailsProvider = FutureProvider.autoDispose.family<HousingListing, int>((ref, id) async {
  return ref.read(authRepoProvider).api.getListingDetails(id);
});

final myListingsProvider = FutureProvider.autoDispose<List<HousingListing>>((ref) async {
  return ref.read(authRepoProvider).api.getMyListings();
});

final receivedRequestsProvider = FutureProvider.autoDispose<List<HousingRequest>>((ref) async {
  return ref.read(authRepoProvider).api.getReceivedRequests();
});

final sentRequestsProvider = FutureProvider.autoDispose<List<HousingRequest>>((ref) async {
  return ref.read(authRepoProvider).api.getSentRequests();
});
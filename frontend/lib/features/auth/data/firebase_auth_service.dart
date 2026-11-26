import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/errors/auth_exception.dart';

/// Thrown when the password is right but the email address is not verified yet
/// (the app then shows the "check your inbox" screen).
class EmailNotVerifiedException implements Exception {
  const EmailNotVerifiedException();
}

/// The user closed the Google account picker: not an error, show nothing.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// FirebaseAuth (email/password + Google). It only proves who the user is:
/// the Firebase ID token is then exchanged for our own JWT (POST /api/auth/firebase/).
class FirebaseAuthService {
  // "Web" OAuth client of the Firebase project (client_type 3 in google-services.json)
  static const _googleServerClientId =
      '647651381595-mjrfh82hqbt0sbp7urh9jefu6gghf6b4.apps.googleusercontent.com';

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  Future<void>? _googleReady;

  /// Firebase uid of the signed-in user (needed by the chat), null if signed out.
  String? get uid => _auth.currentUser?.uid;

  String? get email => _auth.currentUser?.email;

  /// Email/password login. Returns the Firebase ID token.
  Future<String> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final user = credential.user!;
      if (!user.emailVerified) throw const EmailNotVerifiedException();
      return (await user.getIdToken())!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Creates the Firebase account and sends the verification email.
  /// The name is also stored on the Firebase account: the backend uses it if the app loses the
  /// names typed at sign-up (verified later from another device...).
  Future<void> signUpWithEmail(String email, String password, {String? displayName}) async {
    final fb.UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
    final user = credential.user!;
    try {
      if (displayName != null && displayName.isNotEmpty) await user.updateDisplayName(displayName);
    } catch (_) {}
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // The account exists: the verify screen still opens and its "Resend email" button retries
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Your session expired. Log in again.');
    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// After the user clicked the link in the email: a fresh ID token that says "verified",
  /// or null if the email is still not verified.
  Future<String?> verifiedIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Your session expired. Log in again.');
    try {
      await user.reload();
      final fresh = _auth.currentUser!;
      if (!fresh.emailVerified) return null;
      // true = new token: the cached one still says "not verified" for up to 1 hour
      return await fresh.getIdToken(true);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Google Sign-In (account picker) -> Firebase. Returns the Firebase ID token.
  Future<String> signInWithGoogle() async {
    try {
      _googleReady ??= GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
      await _googleReady;
      final account = await GoogleSignIn.instance.authenticate();
      final googleIdToken = account.authentication.idToken;
      if (googleIdToken == null) throw AuthException('Google did not return an ID token. Try again.');
      final credential = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: googleIdToken),
      );
      return (await credential.user!.getIdToken())!;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const SignInCancelled();
      throw AuthException('Google sign-in failed (${e.code.name}). Try again.');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> signOut() async {
    if (_googleReady != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  /// Best effort when the account is deleted (Firebase may require a recent login).
  Future<void> deleteFirebaseUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {}
  }

  String _message(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'This email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Log in instead.';
      case 'weak-password':
        return 'The password is too weak (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'account-exists-with-different-credential':
        return 'This email is already used with another sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return e.message ?? 'Authentication failed. Try again.';
    }
  }
}

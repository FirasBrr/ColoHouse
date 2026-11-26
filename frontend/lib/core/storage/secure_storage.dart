import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );    

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  // Names typed at sign-up, kept with their email until the account is created on the backend
  // (after the email is verified, from the verify screen or from a later login)
  static const _kPendingEmail = 'pending_email';
  static const _kPendingFirst = 'pending_first_name';
  static const _kPendingLast = 'pending_last_name';

  Future<void> savePendingNames(String email, String firstName, String lastName) async {
    await _storage.write(key: _kPendingEmail, value: email.trim().toLowerCase());
    await _storage.write(key: _kPendingFirst, value: firstName);
    await _storage.write(key: _kPendingLast, value: lastName);
  }

  /// (firstName, lastName) saved for this email at sign-up, or (null, null).
  Future<(String?, String?)> pendingNamesFor(String? email) async {
    final saved = await _storage.read(key: _kPendingEmail);
    if (email == null || saved == null || saved != email.trim().toLowerCase()) return (null, null);
    return (await _storage.read(key: _kPendingFirst), await _storage.read(key: _kPendingLast));
  }

  Future<void> clearPendingNames() async {
    await _storage.delete(key: _kPendingEmail);
    await _storage.delete(key: _kPendingFirst);
    await _storage.delete(key: _kPendingLast);
  }
}
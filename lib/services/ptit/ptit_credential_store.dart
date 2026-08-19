import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists PTIT login credentials securely using the device keychain/keystore.
class PtitCredentialStore {
  static const _keyUsername = 'ptit_username';
  static const _keyPassword = 'ptit_password';

  final FlutterSecureStorage _storage;

  const PtitCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save({required String username, required String password}) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<({String username, String password})?> load() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    if (username == null || password == null) return null;
    return (username: username, password: password);
  }

  Future<bool> hasCredentials() async {
    final creds = await load();
    return creds != null;
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
  }
}

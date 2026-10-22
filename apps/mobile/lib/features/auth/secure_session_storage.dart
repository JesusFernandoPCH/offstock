import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session in Keystore/Keychain-backed storage instead of plain SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _store = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _store.containsKey(key: supabasePersistSessionKey);

  @override
  Future<String?> accessToken() => _store.read(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(key: supabasePersistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(key: supabasePersistSessionKey);
}

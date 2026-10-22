import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// App lock behind the phone's own biometrics. See docs/adr/0006-biometric-app-lock.md.
class BiometricLock {
  final _auth = LocalAuthentication();
  static const _store = FlutterSecureStorage();
  static const _enabledKey = 'biometric_lock_enabled';
  static const _askedKey = 'biometric_lock_asked';

  Future<bool> get supported async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get enabled async => await _store.read(key: _enabledKey) == '1';

  Future<bool> get asked async => await _store.read(key: _askedKey) == '1';

  Future<void> setEnabled(bool on) async {
    await _store.write(key: _askedKey, value: '1');
    await _store.write(key: _enabledKey, value: on ? '1' : '0');
  }

  /// True only when the phone confirmed the owner's biometrics.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirma que eres tú para entrar a Offstock',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Called on sign-out so the next person on this phone decides for themselves.
  Future<void> clear() async {
    await _store.delete(key: _enabledKey);
    await _store.delete(key: _askedKey);
  }
}

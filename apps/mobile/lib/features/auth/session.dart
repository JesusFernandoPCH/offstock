import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'biometric_lock.dart';

/// Bump when the terms change; everyone is asked to accept again.
const termsVersion = '2026-10-21';

/// How long the app may sit in the background before it asks for biometrics again.
const relockAfter = Duration(minutes: 5);

enum Stage { loading, signedOut, locked, needsTerms, needsBusiness, offerBiometric, ready, failed }

/// Where the user is in the entry flow. Every gate except the device lock is decided by the database.
class AppSession extends ChangeNotifier with WidgetsBindingObserver {
  AppSession(this.db, {required this.lock, this.googleWebClientId = ''}) {
    WidgetsBinding.instance.addObserver(this);
    _sub = db.auth.onAuthStateChange.listen((change) {
      const relevant = {AuthChangeEvent.initialSession, AuthChangeEvent.signedIn, AuthChangeEvent.signedOut};
      if (relevant.contains(change.event)) refresh();
    });
  }

  final SupabaseClient db;
  final BiometricLock lock;
  final String googleWebClientId;
  late final StreamSubscription<AuthState> _sub;
  Future<void>? _googleReady;
  bool _unlocked = false;
  DateTime? _backgroundSince;

  Stage stage = Stage.loading;
  String? businessId;
  String? businessName;
  String? businessType;
  String? role;

  bool get isDemo => db.auth.currentUser?.isAnonymous ?? false;
  bool get googleEnabled => googleWebClientId.isNotEmpty;
  bool get isOwner => role == 'owner';

  Future<void> refresh() async {
    if (db.auth.currentUser == null) return _set(Stage.signedOut);
    // Checked before any network call: a locked phone shows nothing, online or not.
    if (!isDemo && !_unlocked && await lock.enabled) return _set(Stage.locked);
    try {
      await db.rpc('accept_invitations');
      final terms = await db.from('terms_acceptances').select('version').eq('version', termsVersion).maybeSingle();
      if (terms == null) return _set(Stage.needsTerms);

      // ponytail: first membership wins; add a business picker when someone actually has two.
      final m = await db.from('memberships').select('business_id, role, businesses(name, type)').limit(1).maybeSingle();
      if (m == null) return _set(Stage.needsBusiness);
      businessId = m['business_id'] as String;
      role = m['role'] as String;
      final business = m['businesses'] as Map;
      businessName = business['name'] as String;
      businessType = business['type'] as String;

      if (!isDemo && !await lock.asked && await lock.supported) return _set(Stage.offerBiometric);
      _set(Stage.ready);
    } catch (e) {
      debugPrint('session refresh failed: $e');
      _set(Stage.failed);
    }
  }

  Future<void> startDemo() => db.auth.signInAnonymously();

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await (_googleReady ??= google.initialize(serverClientId: googleWebClientId));
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return; // the user closed the sheet; not an error
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Google returned no ID token');
    _unlocked = true; // they just proved who they are
    await db.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  }

  Future<void> sendCode(String email) => db.auth.signInWithOtp(email: email.trim());

  Future<void> verifyCode(String email, String code) async {
    _unlocked = true;
    await db.auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code.trim());
  }

  Future<void> unlock() async {
    if (await lock.authenticate()) {
      _unlocked = true;
      await refresh();
    }
  }

  Future<void> answerBiometricOffer(bool wantsIt) async {
    final ok = wantsIt && await lock.authenticate();
    await lock.setEnabled(ok);
    if (ok) _unlocked = true;
    await refresh();
  }

  Future<void> acceptTerms() async {
    await db.from('terms_acceptances').insert({'version': termsVersion});
    await refresh();
  }

  Future<void> createBusiness(String name, String type) async {
    await db.rpc('create_business', params: {'p_name': name.trim(), 'p_type': type});
    await refresh();
  }

  Future<void> signOut() async {
    _unlocked = false;
    await lock.clear();
    if (_googleReady != null) await GoogleSignIn.instance.signOut();
    await db.auth.signOut();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _backgroundSince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      if (since != null && DateTime.now().difference(since) >= relockAfter) {
        _unlocked = false;
        refresh();
      }
    }
  }

  void _set(Stage next) {
    if (next == Stage.signedOut) businessId = businessName = businessType = role = null;
    stage = next;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bump when the terms change; everyone is asked to accept again.
const termsVersion = '2026-10-21';

enum Stage { loading, signedOut, needsTerms, needsBusiness, ready, failed }

/// Where the user is in the entry flow. Every gate is decided by the database, not local flags.
class AppSession extends ChangeNotifier {
  AppSession(this.db) {
    _sub = db.auth.onAuthStateChange.listen((change) {
      const relevant = {AuthChangeEvent.initialSession, AuthChangeEvent.signedIn, AuthChangeEvent.signedOut};
      if (relevant.contains(change.event)) refresh();
    });
  }

  final SupabaseClient db;
  late final StreamSubscription<AuthState> _sub;

  Stage stage = Stage.loading;
  String? businessId;
  String? businessName;
  String? role;

  bool get isDemo => db.auth.currentUser?.isAnonymous ?? false;

  Future<void> refresh() async {
    if (db.auth.currentUser == null) return _set(Stage.signedOut);
    try {
      await db.rpc('accept_invitations');
      final terms = await db.from('terms_acceptances').select('version').eq('version', termsVersion).maybeSingle();
      if (terms == null) return _set(Stage.needsTerms);

      // ponytail: first membership wins; add a business picker when someone actually has two.
      final m = await db.from('memberships').select('business_id, role, businesses(name)').limit(1).maybeSingle();
      if (m == null) return _set(Stage.needsBusiness);
      businessId = m['business_id'] as String;
      role = m['role'] as String;
      businessName = (m['businesses'] as Map)['name'] as String;
      _set(Stage.ready);
    } catch (e) {
      debugPrint('session refresh failed: $e');
      _set(Stage.failed);
    }
  }

  Future<void> startDemo() => db.auth.signInAnonymously();

  Future<void> sendCode(String email) => db.auth.signInWithOtp(email: email.trim());

  Future<void> verifyCode(String email, String code) =>
      db.auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code.trim());

  Future<void> acceptTerms() async {
    await db.from('terms_acceptances').insert({'version': termsVersion});
    await refresh();
  }

  Future<void> createBusiness(String name, String type) async {
    await db.rpc('create_business', params: {'p_name': name.trim(), 'p_type': type});
    await refresh();
  }

  Future<void> signOut() => db.auth.signOut();

  void _set(Stage next) {
    if (next != Stage.ready) businessId = businessName = role = null;
    stage = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

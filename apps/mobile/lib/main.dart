import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/tokens.dart';
import 'core/widgets/tactile_button.dart';
import 'features/auth/biometric_lock.dart';
import 'features/auth/lock_screens.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/secure_session_storage.dart';
import 'features/auth/session.dart';
import 'features/auth/terms_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

// Run with: flutter run --dart-define-from-file=../../.env
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _emailLogin = bool.fromEnvironment('EMAIL_LOGIN');
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    throw StateError('Missing Supabase config. Run with --dart-define-from-file=../../.env');
  }
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
    authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );
  final session = AppSession(Supabase.instance.client, lock: BiometricLock(), googleWebClientId: _googleWebClientId);
  runApp(OffstockApp(session: session));
}

/// MaterialApp is plumbing only (routing, localization, a11y). Every visible component is our own.
class OffstockApp extends StatelessWidget {
  const OffstockApp({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offstock',
      debugShowCheckedModeBanner: false,
      theme: offstockTheme(OffstockColors.light, Brightness.light),
      darkTheme: offstockTheme(OffstockColors.dark, Brightness.dark),
      builder: offstockSurface,
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => AnimatedSwitcher(
          duration: Motion.base,
          child: KeyedSubtree(key: ValueKey(session.stage), child: _screenFor(session)),
        ),
      ),
    );
  }

  Widget _screenFor(AppSession s) => switch (s.stage) {
        Stage.loading => const _Splash(),
        Stage.signedOut => LoginScreen(
            emailLogin: _emailLogin,
            onGoogle: s.googleEnabled ? s.signInWithGoogle : null,
            onDemo: s.startDemo,
            onSendCode: s.sendCode,
            onVerify: s.verifyCode,
          ),
        Stage.locked => LockScreen(onUnlock: s.unlock, onSignOut: s.signOut),
        Stage.offerBiometric => BiometricOfferScreen(onAnswer: s.answerBiometricOffer),
        Stage.needsTerms => TermsScreen(version: termsVersion, onAccept: s.acceptTerms),
        Stage.needsBusiness => OnboardingScreen(onCreate: s.createBusiness),
        Stage.ready => HomeScreen(session: s),
        Stage.failed => _Retry(onRetry: s.refresh),
      };
}

ThemeData offstockTheme(OffstockColors c, Brightness b) => ThemeData(
      brightness: b,
      fontFamily: OffstockType.family,
      scaffoldBackgroundColor: c.bg,
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.25),
        selectionHandleColor: c.accent,
      ),
      colorScheme: ColorScheme(
        brightness: b,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.hold,
        onSecondary: c.onHold,
        error: c.danger,
        onError: c.surface,
        surface: c.surface,
        onSurface: c.ink,
      ),
    );

/// Paints the app background, gives text fields the Material ancestor they require, and shrinks
/// every screen above the keyboard (the Scaffold) so focused fields are never hidden.
Widget offstockSurface(BuildContext context, Widget? child) {
  final c = OffstockColors.of(context);
  return Scaffold(
    backgroundColor: c.bg,
    resizeToAvoidBottomInset: true,
    body: DefaultTextStyle(style: OffstockType.body.copyWith(color: c.ink), child: child!),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Center(child: Text('Offstock', style: OffstockType.title.copyWith(color: c.inkSoft)));
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text('No pudimos conectar con Offstock.', style: OffstockType.heading.copyWith(color: c.ink)),
            Text('Revisa tu conexión a internet e inténtalo de nuevo.',
                style: OffstockType.body.copyWith(color: c.inkSoft)),
            TactileButton(label: 'Reintentar', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

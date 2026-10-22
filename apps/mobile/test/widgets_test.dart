import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/theme/tokens.dart';
import 'package:offstock/core/widgets/gallery_screen.dart';
import 'package:offstock/core/widgets/tactile_button.dart';
import 'package:offstock/features/auth/lock_screens.dart';
import 'package:offstock/features/auth/login_screen.dart';
import 'package:offstock/features/auth/terms_screen.dart';
import 'package:offstock/features/onboarding/onboarding_screen.dart';
import 'package:offstock/main.dart';

Widget _app(Widget home) => MaterialApp(
      theme: offstockTheme(OffstockColors.light, Brightness.light),
      builder: offstockSurface,
      home: home,
    );

void main() {
  testWidgets('TactileButton fires only when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Column(children: [
      TactileButton(label: 'Cobrar', onPressed: () => taps++),
      const TactileButton(label: 'Bloqueado', onPressed: null),
    ])));
    await tester.tap(find.text('Cobrar'));
    await tester.tap(find.text('Bloqueado'));
    expect(taps, 1);
  });

  testWidgets('scanning adds a hang tag and updates the total', (tester) async {
    await tester.pumpWidget(_app(const GalleryScreen()));
    expect(find.text('Escanea una prenda para empezar la venta.'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('Playera básica cuello redondo'), findsOneWidget);
    expect(find.text(r'$249.00'), findsNWidgets(2)); // tag price + total

    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(find.text('Escanea una prenda para empezar la venta.'), findsOneWidget);
  });

  testWidgets('login: email, code, then verify', (tester) async {
    String? sentTo;
    (String, String)? verified;
    await tester.pumpWidget(_app(LoginScreen(
      onDemo: () async {},
      onSendCode: (email) async => sentTo = email,
      onVerify: (email, code) async => verified = (email, code),
    )));

    await tester.enterText(find.byType(TextField), 'no-es-correo');
    await tester.tap(find.text('Enviarme un código'));
    expect(sentTo, isNull, reason: 'invalid email keeps the button disabled');

    await tester.enterText(find.byType(TextField), 'ana@tienda.mx');
    await tester.pump();
    await tester.tap(find.text('Enviarme un código'));
    await tester.pumpAndSettle();
    expect(sentTo, 'ana@tienda.mx');

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(verified, ('ana@tienda.mx', '123456'));
  });

  testWidgets('login: failures show a message and keep the user on the step', (tester) async {
    await tester.pumpWidget(_app(LoginScreen(
      onDemo: () async => throw Exception('offline'),
      onSendCode: (_) async => throw Exception('rate limited'),
      onVerify: (_, _) async {},
    )));

    await tester.enterText(find.byType(TextField), 'ana@tienda.mx');
    await tester.pump();
    await tester.tap(find.text('Enviarme un código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos enviar el código'), findsOneWidget);
    expect(find.text('Enviarme un código'), findsOneWidget);

    await tester.tap(find.text('Probar la demo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos abrir la demo'), findsOneWidget);
  });

  testWidgets('login: email can be turned off, demo stays', (tester) async {
    await tester.pumpWidget(_app(LoginScreen(
      emailLogin: false,
      onDemo: () async {},
      onSendCode: (_) async {},
      onVerify: (_, _) async {},
    )));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Probar la demo'), findsOneWidget);
  });

  testWidgets('login: Google button shows only when configured', (tester) async {
    var google = 0;
    Widget login({Future<void> Function()? onGoogle}) => _app(LoginScreen(
          emailLogin: false,
          onGoogle: onGoogle,
          onDemo: () async {},
          onSendCode: (_) async {},
          onVerify: (_, _) async {},
        ));

    await tester.pumpWidget(login());
    expect(find.text('Continuar con Google'), findsNothing);

    await tester.pumpWidget(login(onGoogle: () async => google++));
    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();
    expect(google, 1);
  });

  testWidgets('lock screen prompts on open and offers another account', (tester) async {
    var prompts = 0, signOuts = 0;
    await tester.pumpWidget(_app(LockScreen(onUnlock: () async => prompts++, onSignOut: () async => signOuts++)));
    await tester.pump();
    expect(prompts, 1, reason: 'biometric prompt opens without a tap');

    await tester.tap(find.text('Desbloquear'));
    await tester.tap(find.text('Entrar con otra cuenta'));
    expect((prompts, signOuts), (2, 1));
  });

  testWidgets('biometric offer reports the answer', (tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(_app(BiometricOfferScreen(onAnswer: (yes) async => answers.add(yes))));
    await tester.tap(find.text('Activar huella'));
    await tester.tap(find.text('Ahora no'));
    expect(answers, [true, false]);
  });

  testWidgets('terms: accepting calls back once', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(_app(TermsScreen(version: '2026-10-21', onAccept: () async => accepted++)));
    await tester.tap(find.text('Aceptar y continuar'));
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('onboarding: needs a name and a type', (tester) async {
    (String, String)? created;
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(OnboardingScreen(onCreate: (name, type) async => created = (name, type))));

    await tester.tap(find.text('Crear mi negocio'));
    expect(created, isNull);

    await tester.enterText(find.byType(TextField), 'Tienda Lupita');
    await tester.tap(find.text('Ropa y calzado'));
    await tester.pump();
    await tester.tap(find.text('Crear mi negocio'));
    await tester.pumpAndSettle();
    expect(created, ('Tienda Lupita', 'clothing'));
  });
}

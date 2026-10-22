import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/offstock_field.dart';
import '../../core/widgets/tactile_button.dart';

/// Email + 6-digit code, or a no-signup demo. Google joins here once its OAuth client exists.
/// Email login needs an SMTP provider in the cloud project, so it is opt-in via [emailLogin].
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onDemo,
    required this.onSendCode,
    required this.onVerify,
    this.emailLogin = true,
    this.onGoogle,
  });

  final bool emailLogin;

  /// Null hides the button (no OAuth client configured for this build).
  final Future<void> Function()? onGoogle;
  final Future<void> Function() onDemo;
  final Future<void> Function(String email) onSendCode;
  final Future<void> Function(String email, String code) onVerify;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _run(Future<void> Function() action, String failure, {VoidCallback? onDone}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      onDone?.call();
    } catch (_) {
      _error = failure;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _send() => _run(
        () => widget.onSendCode(_email.text),
        'No pudimos enviar el código. Revisa el correo e inténtalo de nuevo.',
        onDone: () => _codeSent = true,
      );

  void _verify() => _run(
        () => widget.onVerify(_email.text, _code.text),
        'El código no es válido o ya venció. Pide uno nuevo.',
      );

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Off'),
              TextSpan(text: 'stock', style: TextStyle(color: c.accentText)),
            ]),
            style: OffstockType.total.copyWith(
              fontSize: 64,
              color: c.ink,
              height: 0.95,
              fontVariations: const [FontVariation('wght', 800), FontVariation('opsz', 96), FontVariation('wdth', 78)],
            ),
          ),
          const SizedBox(height: 8),
          Text('Funciona Aunque Te Salgas.', style: OffstockType.heading.copyWith(color: c.ink)),
          const SizedBox(height: 40),
          if (widget.onGoogle != null && !_codeSent) ...[
            TactileButton(
              label: 'Continuar con Google',
              onPressed: _busy ? null : () => _run(widget.onGoogle!, 'No pudimos entrar con Google. Inténtalo de nuevo.'),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.emailLogin && !_codeSent) ...[
            OffstockField(
              label: 'Tu correo',
              controller: _email,
              hint: 'ana@tienda.mx',
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _emailOk && !_busy ? _send() : null,
            ),
            const SizedBox(height: 16),
            TactileButton(label: 'Enviarme un código', onPressed: _emailOk && !_busy ? _send : null),
          ] else if (widget.emailLogin) ...[
            Text('Te enviamos un código de 6 dígitos a ${_email.text.trim()}.',
                style: OffstockType.body.copyWith(color: c.inkSoft)),
            const SizedBox(height: 16),
            OffstockField(
              label: 'Código',
              controller: _code,
              hint: '000000',
              keyboardType: TextInputType.number,
              maxLength: 6,
              big: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TactileButton(label: 'Entrar', onPressed: _code.text.trim().length == 6 && !_busy ? _verify : null),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSent = false),
              child: Text('Usar otro correo', style: OffstockType.label.copyWith(color: c.accentText)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: OffstockType.label.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 40),
          Text('¿Solo quieres ver cómo funciona?', style: OffstockType.label.copyWith(color: c.inkSoft)),
          const SizedBox(height: 12),
          TactileButton(
            label: 'Probar la demo',
            secondary: true,
            onPressed: _busy ? null : () => _run(widget.onDemo, 'No pudimos abrir la demo. Revisa tu conexión.'),
          ),
        ],
      ),
    );
  }
}

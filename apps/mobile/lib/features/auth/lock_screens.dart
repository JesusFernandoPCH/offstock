import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/tactile_button.dart';

/// Shown while a signed-in session waits for the owner's biometrics. Prompts right away.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock, required this.onSignOut});

  final Future<void> Function() onUnlock;
  final Future<void> Function() onSignOut;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUnlock());
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Offstock está bloqueado',
      body: 'Usa tu huella o tu rostro para seguir vendiendo.',
      children: [
        TactileButton(label: 'Desbloquear', onPressed: widget.onUnlock),
        TactileButton(label: 'Entrar con otra cuenta', secondary: true, onPressed: widget.onSignOut),
      ],
    );
  }
}

/// One-time offer after the first real sign-in on this phone.
class BiometricOfferScreen extends StatelessWidget {
  const BiometricOfferScreen({super.key, required this.onAnswer});

  final Future<void> Function(bool wantsIt) onAnswer;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Entra más rápido',
      body: 'Desbloquea Offstock con la huella o el rostro que ya usas en este teléfono. '
          'Tu huella nunca sale del teléfono: Offstock solo recibe un sí o un no.',
      children: [
        TactileButton(label: 'Activar huella', onPressed: () => onAnswer(true)),
        TactileButton(label: 'Ahora no', secondary: true, onPressed: () => onAnswer(false)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.body, required this.children});

  final String title, body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final color = OffstockColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(title, style: OffstockType.title.copyWith(color: color.ink)),
            const SizedBox(height: 12),
            Text(body, style: OffstockType.body.copyWith(color: color.inkSoft)),
            const Spacer(),
            ...[for (final child in children) ...[child, const SizedBox(height: 12)]],
          ],
        ),
      ),
    );
  }
}

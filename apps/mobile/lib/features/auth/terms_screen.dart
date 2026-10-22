import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/tactile_button.dart';

/// Plain-language summary. The full terms and privacy notice (LFPDPPP) land in Phase 7.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.version, required this.onAccept});

  final String version;
  final Future<void> Function() onAccept;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _busy = false;
  String? _error;

  static const _points = [
    'Guardamos los datos de tu negocio (productos, ventas, empleados) para que la app funcione en todos tus teléfonos.',
    'Tus datos son tuyos: puedes exportarlos o borrar tu cuenta cuando quieras.',
    'Offstock es un proyecto de portafolio. La facturación es de prueba y no tiene validez fiscal.',
    'Si cambiamos estos términos, te los volveremos a mostrar antes de seguir.',
  ];

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } catch (_) {
      _error = 'No pudimos guardar tu aceptación. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Antes de empezar', style: OffstockType.title.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            Text('Términos y aviso de privacidad, versión ${widget.version}.',
                style: OffstockType.label.copyWith(color: c.inkSoft)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: _points.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, i) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: c.accentText, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(_points[i], style: OffstockType.body.copyWith(color: c.ink))),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: OffstockType.label.copyWith(color: c.danger)),
              const SizedBox(height: 12),
            ],
            TactileButton(label: 'Aceptar y continuar', onPressed: _busy ? null : _accept),
          ],
        ),
      ),
    );
  }
}

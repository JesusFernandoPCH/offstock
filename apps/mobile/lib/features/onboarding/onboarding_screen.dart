import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/offstock_field.dart';
import '../../core/widgets/tactile_button.dart';

/// Values match the `business_type` enum in the database. The type picks the catalog template.
const businessTypes = [
  (value: 'clothing', title: 'Ropa y calzado', detail: 'Tallas, colores y códigos por prenda'),
  (value: 'food', title: 'Comida para llevar', detail: 'Venta en mostrador con categorías de menú'),
  (value: 'tech', title: 'Tecnología', detail: 'Marcas, modelos y códigos de barras'),
  (value: 'other', title: 'Otro giro', detail: 'Productos con precio y existencias'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCreate});

  final Future<void> Function(String name, String type) onCreate;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  String? _type;
  bool _busy = false;
  String? _error;

  bool get _ready => _name.text.trim().isNotEmpty && _type != null && !_busy;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCreate(_name.text, _type!);
    } catch (_) {
      _error = 'No pudimos crear tu negocio. Revisa tu conexión e inténtalo de nuevo.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        children: [
          Text('Cuéntanos de tu negocio', style: OffstockType.title.copyWith(color: c.ink)),
          const SizedBox(height: 24),
          OffstockField(
            label: 'Nombre del negocio',
            controller: _name,
            hint: 'Tienda Lupita',
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),
          Text('¿Qué vendes?', style: OffstockType.label.copyWith(color: c.inkSoft)),
          const SizedBox(height: 8),
          for (final t in businessTypes) ...[
            _TypeTile(
              title: t.title,
              detail: t.detail,
              selected: _type == t.value,
              onTap: () => setState(() => _type = t.value),
            ),
            const SizedBox(height: 10),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: OffstockType.label.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 18),
          TactileButton(label: 'Crear mi negocio', onPressed: _ready ? _create : null),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.title, required this.detail, required this.selected, required this.onTap});

  final String title, detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.accent : c.line, width: selected ? 2 : 1.5),
            boxShadow: [BoxShadow(color: selected ? c.accentLip : c.line, offset: Offset(0, selected ? 3 : 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(title, style: OffstockType.heading.copyWith(fontSize: 17, color: c.ink)),
              Text(detail, style: OffstockType.label.copyWith(fontSize: 13, color: c.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

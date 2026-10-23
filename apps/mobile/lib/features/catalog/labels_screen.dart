import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/tactile_button.dart';
import 'catalog_repo.dart';
import 'labels_pdf.dart';
import 'product_form_screen.dart' show CountRow;
import 'templates.dart';

/// Pick how many labels each variant needs (defaults to pieces in stock) and print or share the sheet.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key, required this.item, required this.output});

  final CatalogItem item;

  /// Hands the finished PDF to the system print dialog, or to the share sheet when [share] is true.
  final Future<void> Function(Uint8List pdf, {required bool share}) output;

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  late final _copies = {for (final v in widget.item.variants) v.id: TextEditingController(text: '${v.onHand}')};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _copies.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _count(VariantRow v) => int.tryParse(_copies[v.id]!.text.trim())?.clamp(0, 999) ?? 0;

  int get _total => widget.item.variants.fold(0, (sum, v) => sum + _count(v));

  Future<void> _go({required bool share}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pdf = await buildLabelsPdf([
        for (final v in widget.item.variants)
          if (v.barcode != null && _count(v) > 0)
            LabelSpec(
              name: widget.item.name,
              variant: variantLabel(v.attrs),
              priceCents: v.priceCents,
              barcode: v.barcode!,
              copies: _count(v),
            ),
      ]);
      await widget.output(pdf, share: share);
    } catch (e) {
      debugPrint('labels failed: $e');
      if (mounted) setState(() => _error = 'No pudimos preparar las etiquetas. Inténtalo de nuevo.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final total = _total;
    final pages = (total / labelsPerPage).ceil();

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Etiquetas', style: OffstockType.title.copyWith(color: c.ink))),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Listo', style: OffstockType.label.copyWith(color: c.accentText)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(widget.item.name, style: OffstockType.heading.copyWith(color: c.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Una etiqueta por pieza. Ajusta cuántas necesitas de cada variante.',
                    style: OffstockType.body.copyWith(color: c.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  for (final v in widget.item.variants)
                    CountRow(
                      label: '${v.attrs.isEmpty ? 'Pieza' : variantLabel(v.attrs)}  ${formatMxn(v.priceCents)}',
                      controller: _copies[v.id]!,
                      code: v.barcode,
                      onChanged: () => setState(() {}),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Text(
                    total == 0
                        ? 'Elige al menos una etiqueta.'
                        : '$total ${total == 1 ? 'etiqueta' : 'etiquetas'} en $pages ${pages == 1 ? 'hoja' : 'hojas'} tamaño carta.',
                    style: OffstockType.label.copyWith(color: c.inkSoft),
                  ),
                  if (_error != null) Text(_error!, style: OffstockType.label.copyWith(color: c.danger)),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: TactileButton(
                          label: 'Compartir PDF',
                          secondary: true,
                          onPressed: _busy || total == 0 ? null : () => _go(share: true),
                        ),
                      ),
                      Expanded(
                        child: TactileButton(
                          label: _busy ? 'Preparando…' : 'Imprimir',
                          onPressed: _busy || total == 0 ? null : () => _go(share: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

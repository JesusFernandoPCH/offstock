import 'package:flutter/widgets.dart';

import '../money.dart';
import '../theme/tokens.dart';
import 'hang_tag.dart';
import 'status_chip.dart';
import 'tactile_button.dart';

/// Phase 0 design-system playground. Replaced by the real sales flow in Phase 3.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.title = 'Venta de Ana', this.onSignOut});

  final String title;
  final VoidCallback? onSignOut;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

typedef _Item = ({String id, String name, String variant, int price});

const _catalog = <_Item>[
  (id: 'p1', name: 'Playera básica cuello redondo', variant: 'Talla M, negro', price: 24900),
  (id: 'p2', name: 'Jeans slim', variant: 'Talla 32, índigo', price: 69900),
  (id: 'p3', name: 'Sudadera con capucha', variant: 'Talla L, gris jaspe', price: 54900),
  (id: 'p4', name: 'Calcetas tobilleras', variant: 'Paquete de 3', price: 12900),
];

class _GalleryScreenState extends State<GalleryScreen> {
  final _cart = <_Item>[];
  int _next = 0;

  void _scan() {
    final item = _catalog[_next++ % _catalog.length];
    if (_cart.any((i) => i.id == item.id)) return;
    setState(() => _cart.add(item));
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final total = _cart.fold(0, (sum, i) => sum + i.price);

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: OffstockType.title.copyWith(color: c.ink))),
                  if (widget.onSignOut != null)
                    GestureDetector(
                      onTap: widget.onSignOut,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Salir', style: OffstockType.label.copyWith(color: c.accentText)),
                      ),
                    )
                  else
                    const StatusChip('En línea', kind: ChipKind.ok),
                ],
              ),
            ),
            Expanded(
              child: _cart.isEmpty
                  ? Center(
                      child: Text('Escanea una prenda para empezar la venta.',
                          style: OffstockType.body.copyWith(color: c.inkSoft)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(30, 8, 16, 16),
                      itemCount: _cart.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final item = _cart[i];
                        return HangTag(
                          key: ValueKey(item.id),
                          swingIn: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(item.name,
                                        style: OffstockType.label.copyWith(fontSize: 15, color: c.ink)),
                                  ),
                                  Text(formatMxn(item.price), style: OffstockType.price.copyWith(color: c.ink)),
                                ],
                              ),
                              Text(item.variant, style: OffstockType.label.copyWith(fontSize: 13, color: c.inkSoft)),
                              const StatusChip('Apartado 15:00', kind: ChipKind.hold),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_cart.length} ${_cart.length == 1 ? 'pieza' : 'piezas'}',
                            style: OffstockType.label.copyWith(color: c.inkSoft)),
                        Text(formatMxn(total), style: OffstockType.total.copyWith(color: c.ink)),
                      ],
                    ),
                    Row(
                      spacing: 10,
                      children: [
                        Expanded(child: TactileButton(label: 'Escanear', secondary: true, onPressed: _scan)),
                        Expanded(
                          child: TactileButton(
                            label: 'Cobrar',
                            onPressed: _cart.isEmpty ? null : () => setState(_cart.clear),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

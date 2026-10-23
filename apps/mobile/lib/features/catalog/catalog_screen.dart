import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/offstock_field.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/tactile_button.dart';
import 'catalog_repo.dart';
import 'scanner_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.load, this.onAdd, this.scan});

  final Future<List<CatalogItem>> Function() load;

  /// Null for employees. Resolves to true when a product was created; [barcode] prefills its code.
  final Future<bool?> Function({String? barcode})? onAdd;

  /// Opens the camera and resolves to a code, or null if the person backed out.
  final Future<String?> Function()? scan;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  List<CatalogItem>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } catch (e) {
      debugPrint('catalog load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _add({String? barcode}) async {
    if (await widget.onAdd!(barcode: barcode) == true) await _reload();
  }

  Future<void> _scan() async {
    final code = await widget.scan!();
    if (code != null && mounted) setState(() => _search.text = code);
  }

  List<CatalogItem> get _visible {
    final q = _search.text.trim().toLowerCase();
    final items = _items ?? const [];
    if (q.isEmpty) return items;
    return [
      for (final i in items)
        if (i.name.toLowerCase().contains(q) ||
            (i.category?.toLowerCase().contains(q) ?? false) ||
            i.variants.any((v) => v.barcode == q))
          i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final items = _items;

    final Widget body;
    if (_failed) {
      body = _Message(
        title: 'No pudimos cargar el catálogo.',
        detail: 'Revisa tu conexión e inténtalo de nuevo.',
        action: TactileButton(label: 'Reintentar', onPressed: _reload),
      );
    } else if (items == null) {
      body = Center(child: Text('Cargando catálogo…', style: OffstockType.body.copyWith(color: c.inkSoft)));
    } else if (items.isEmpty) {
      body = widget.onAdd != null
          ? _Message(
              title: 'Tu catálogo está vacío.',
              detail: 'Agrega tu primer producto con su foto, su precio y las piezas que tienes en tienda.',
              action: TactileButton(label: 'Agregar producto', onPressed: _add),
            )
          : const _Message(title: 'Aún no hay productos.', detail: 'El dueño del negocio todavía no los agrega.');
    } else {
      final visible = _visible;
      body = RefreshIndicator(
        color: c.accentText,
        backgroundColor: c.surface,
        onRefresh: _reload,
        child: visible.isEmpty
            ? ListView(children: [
                if (acceptBarcode(_search.text) case final code?)
                  _Message(
                    title: 'El código $code no está en tu catálogo.',
                    detail: widget.onAdd != null
                        ? 'Créalo ahora y el código quedará ligado al producto.'
                        : 'Pídele al dueño del negocio que lo agregue.',
                    action: widget.onAdd == null
                        ? null
                        : TactileButton(label: 'Crear producto con este código', onPressed: () => _add(barcode: code)),
                  )
                else ...[
                  const SizedBox(height: 48),
                  Center(child: Text('Nada coincide con tu búsqueda.', style: OffstockType.body.copyWith(color: c.inkSoft))),
                ],
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ProductRow(item: visible[i]),
              ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
            child: Row(
              children: [
                Expanded(child: Text('Catálogo', style: OffstockType.title.copyWith(color: c.ink))),
                if (widget.onAdd != null && (items?.isNotEmpty ?? false))
                  TactileButton(label: 'Agregar', onPressed: _add),
              ],
            ),
          ),
          if (items?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: OffstockField(
                      label: 'Buscar por nombre, categoría o código',
                      controller: _search,
                      hint: 'Playera, jeans, 7501…',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (widget.scan != null) _ScanButton(onTap: _scan),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Pressable(
      onTap: onTap,
      label: 'Escanear código de barras',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.accentLip, offset: const Offset(0, 3))],
        ),
        child: CustomPaint(painter: _BarsGlyph(color: c.onAccent)),
      ),
    );
  }
}

/// Barcode glyph: uneven vertical bars, drawn so it follows the theme without an icon font.
class _BarsGlyph extends CustomPainter {
  const _BarsGlyph({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const widths = [2.5, 1.5, 3.5, 1.5, 2.5, 1.5, 3.5, 2.0];
    var x = size.width / 2 - 14;
    for (final w in widths) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height / 2 - 10, w, 20), const Radius.circular(0.75)),
        p,
      );
      x += w + 2;
    }
  }

  @override
  bool shouldRepaint(_BarsGlyph old) => old.color != color;
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final prices = item.variants.map((v) => v.priceCents).toSet();
    final price = prices.length == 1 ? formatMxn(prices.first) : 'desde ${formatMxn(item.minPrice)}';
    final detail = [
      if (item.category != null) item.category!,
      if (item.variants.length > 1) '${item.variants.length} variantes',
    ].join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Row(
        spacing: 12,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 64,
              child: item.photoUrl == null
                  ? _Placeholder(name: item.name)
                  : Image.network(
                      item.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _Placeholder(name: item.name),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(item.name, style: OffstockType.label.copyWith(fontSize: 16, color: c.ink)),
                if (detail.isNotEmpty) Text(detail, style: OffstockType.label.copyWith(fontSize: 13, color: c.inkSoft)),
                Text(price, style: OffstockType.price.copyWith(color: c.ink)),
              ],
            ),
          ),
          item.stock > 0
              ? StatusChip('${item.stock} en tienda', kind: ChipKind.ok)
              : const StatusChip('Agotado', kind: ChipKind.danger),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return ColoredBox(
      color: c.line,
      child: Center(
        child: Text(name.characters.first.toUpperCase(), style: OffstockType.title.copyWith(color: c.inkSoft)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail, this.action});

  final String title, detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(title, style: OffstockType.heading.copyWith(color: c.ink)),
          Text(detail, style: OffstockType.body.copyWith(color: c.inkSoft)),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

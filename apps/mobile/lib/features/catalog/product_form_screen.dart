import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/offstock_field.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/tactile_button.dart';
import 'catalog_repo.dart';
import 'templates.dart';

/// New product as numbered steps (photo, basics, variants, pieces). Each step turns green when done,
/// and a pinned bar keeps progress and the save button above the keyboard.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.template,
    required this.onSave,
    required this.takePhoto,
    this.showGuide = false,
    this.onGuideSeen,
  });

  final CatalogTemplate template;
  final Future<void> Function(ProductDraft draft) onSave;
  final Future<Uint8List?> Function() takePhoto;

  /// First visit: explain the steps once.
  final bool showGuide;
  final VoidCallback? onGuideSeen;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  late final _fields = {for (final f in widget.template.fields) f.key: TextEditingController()};
  late final _options = {for (final a in widget.template.axes) a.key: [...a.options]};
  late final _chosen = {for (final a in widget.template.axes) a.key: <String>[]};
  final _stock = <String, TextEditingController>{};
  late bool _guide = widget.showGuide;
  Uint8List? _photo;
  bool _busy = false;
  String? _error;

  bool get _hasAxes => widget.template.axes.isNotEmpty;

  List<Map<String, String>> get _variants => expandVariants({
        // Keep each axis in option order so "CH, M, G" never shows up as "G, CH, M".
        for (final a in widget.template.axes) a.key: [for (final o in _options[a.key]!) if (_chosen[a.key]!.contains(o)) o],
      });

  TextEditingController _stockFor(Map<String, String> attrs) =>
      _stock.putIfAbsent(jsonEncode(attrs), () => TextEditingController(text: '0'));

  int? _parseStock(Map<String, String> v) => switch (_stockFor(v).text.trim()) { '' => 0, final t => int.tryParse(t) };

  bool get _photoDone => _photo != null;
  bool get _basicsDone => _name.text.trim().isNotEmpty && parsePesos(_price.text) != null;
  bool get _axesDone => _chosen.values.any((v) => v.isNotEmpty);
  bool get _piecesDone => _variants.any((v) => (_parseStock(v) ?? 0) > 0);
  List<bool> get _steps => [_photoDone, _basicsDone, if (_hasAxes) _axesDone, _piecesDone];

  @override
  void dispose() {
    for (final c in [_name, _category, _price, _cost, ..._fields.values, ..._stock.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _dismissGuide() {
    setState(() => _guide = false);
    widget.onGuideSeen?.call();
  }

  Future<void> _pickPhoto() async {
    try {
      final bytes = await widget.takePhoto();
      if (bytes != null && mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos abrir la cámara. Revisa el permiso de cámara de Offstock.');
    }
  }

  Future<void> _addOption(VariantAxis axis) async {
    final value = await showDialog<String>(context: context, builder: (_) => _NewOptionDialog(axis: axis));
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    setState(() {
      if (!_options[axis.key]!.contains(v)) _options[axis.key]!.add(v);
      if (!_chosen[axis.key]!.contains(v)) _chosen[axis.key]!.add(v);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final price = parsePesos(_price.text);
    final cost = _cost.text.trim().isEmpty ? null : parsePesos(_cost.text);
    final variants = _variants;
    final stocks = [for (final v in variants) _parseStock(v)];

    String? problem;
    if (name.isEmpty) {
      problem = 'Escribe el nombre del producto (paso 2).';
    } else if (price == null) {
      problem = 'Escribe un precio válido, por ejemplo 249 o 249.50 (paso 2).';
    } else if (_cost.text.trim().isNotEmpty && cost == null) {
      problem = 'El costo no es válido. Déjalo vacío si no lo sabes.';
    } else if (stocks.any((s) => s == null || s < 0)) {
      problem = 'Las piezas deben ser números enteros, sin negativos.';
    }
    if (problem != null) return setState(() => _error = problem);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(ProductDraft(
        name: name,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        attrs: {for (final e in _fields.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
        photo: _photo,
        variants: [
          for (var i = 0; i < variants.length; i++)
            (attrs: variants[i], priceCents: price!, costCents: cost, stock: stocks[i]!),
        ],
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('create product failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No pudimos guardar el producto. Revisa tu conexión e inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final t = widget.template;
    final variants = _variants;
    final steps = _steps;
    var n = 0;

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Nuevo producto', style: OffstockType.title.copyWith(color: c.ink))),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: Text('Cancelar', style: OffstockType.label.copyWith(color: c.accentText)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  AnimatedSize(
                    duration: Motion.base,
                    curve: Curves.easeOut,
                    child: _guide ? _Guide(steps: steps.length, onDismiss: _dismissGuide) : const SizedBox(width: double.infinity),
                  ),
                  _Step(
                    number: ++n,
                    title: 'Foto',
                    hint: 'Recomendada: así tus vendedores la reconocen.',
                    done: _photoDone,
                    child: _PhotoBox(photo: _photo, onTap: _busy ? null : _pickPhoto),
                  ),
                  _Step(
                    number: ++n,
                    title: 'Datos',
                    hint: 'Solo el nombre y el precio son obligatorios.',
                    done: _basicsDone,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OffstockField(
                          label: 'Nombre',
                          controller: _name,
                          hint: 'Ej. Playera básica cuello redondo',
                          maxLength: 120,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          spacing: 12,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: OffstockField(
                                label: 'Precio de venta',
                                controller: _price,
                                hint: 'Ej. 249',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Expanded(
                              child: OffstockField(
                                label: 'Costo (solo tú)',
                                controller: _cost,
                                hint: 'Opcional',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Categoría', style: OffstockType.label.copyWith(color: c.inkSoft)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cat in {...t.categories, if (_category.text.isNotEmpty) _category.text})
                              _Chip(
                                label: cat,
                                selected: _category.text == cat,
                                onTap: () => setState(() => _category.text = _category.text == cat ? '' : cat),
                              ),
                            _Chip(
                              label: '+ Otra',
                              selected: false,
                              onTap: () async {
                                final v = await showDialog<String>(
                                  context: context,
                                  builder: (_) => const _NewOptionDialog(axis: VariantAxis('categoria', 'Categorías', [])),
                                );
                                if (v != null && v.trim().isNotEmpty) setState(() => _category.text = v.trim());
                              },
                            ),
                          ],
                        ),
                        for (final f in t.fields) ...[
                          const SizedBox(height: 16),
                          OffstockField(label: f.label, controller: _fields[f.key]!, hint: 'Opcional', maxLength: 60),
                        ],
                      ],
                    ),
                  ),
                  if (_hasAxes)
                    _Step(
                      number: ++n,
                      title: [t.axes.first.label, for (final a in t.axes.skip(1)) a.label.toLowerCase()].join(' y '),
                      hint: 'Marca las que tienes. Cada combinación será una variante con sus piezas.',
                      done: _axesDone,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final axis in t.axes) ...[
                            Text(axis.label, style: OffstockType.label.copyWith(color: c.inkSoft)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final o in _options[axis.key]!)
                                  _Chip(
                                    label: o,
                                    selected: _chosen[axis.key]!.contains(o),
                                    onTap: () => setState(() {
                                      final list = _chosen[axis.key]!;
                                      list.contains(o) ? list.remove(o) : list.add(o);
                                    }),
                                  ),
                                _Chip(label: '+ Otra', selected: false, onTap: () => _addOption(axis)),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  _Step(
                    number: ++n,
                    title: 'Piezas en tienda',
                    hint: variants.length == 1
                        ? 'Cuántas tienes hoy. Después cambian solas con cada venta.'
                        : '${variants.length} variantes. Cuántas tienes hoy de cada una.',
                    done: _piecesDone,
                    child: Column(
                      children: [
                        for (final v in variants)
                          _CountRow(
                            label: v.isEmpty ? 'Todas' : variantLabel(v),
                            controller: _stockFor(v),
                            onChanged: () => setState(() {}),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _SaveBar(
              done: steps.where((d) => d).length,
              total: steps.length,
              busy: _busy,
              error: _error,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.steps, required this.onDismiss});

  final int steps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.hold, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text('Tu primer producto', style: OffstockType.heading.copyWith(color: c.onHold)),
          Text(
            'Sigue los $steps pasos en orden. Cada uno se pone verde al completarlo. '
            'Solo el nombre y el precio son obligatorios.',
            style: OffstockType.body.copyWith(color: c.onHold),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Pressable(
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Entendido', style: OffstockType.label.copyWith(fontSize: 15, color: c.onHold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered card. The badge becomes a green check when the step is done.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.hint, required this.done, required this.child});

  final int number;
  final String title, hint;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return AnimatedContainer(
      duration: Motion.base,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? c.ok.withValues(alpha: 0.6) : c.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 12,
            children: [
              AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: child,
                ),
                child: Container(
                  key: ValueKey(done),
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? c.ok : const Color(0x00000000),
                    shape: BoxShape.circle,
                    border: done ? null : Border.all(color: c.accent, width: 2),
                  ),
                  child: Text(
                    done ? '✓' : '$number',
                    style: OffstockType.label.copyWith(fontSize: 15, color: done ? c.surface : c.accentText),
                  ),
                ),
              ),
              Expanded(child: Text(title, style: OffstockType.heading.copyWith(color: c.ink))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(42, 2, 0, 14),
            child: Text(hint, style: OffstockType.label.copyWith(fontSize: 13, color: c.inkSoft)),
          ),
          child,
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.done, required this.total, required this.busy, required this.error, required this.onSave});

  final int done, total;
  final bool busy;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: total == 0 ? 0 : done / total),
                    duration: Motion.slow,
                    curve: Curves.easeOutBack,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: c.line,
                      color: done == total ? c.ok : c.accent,
                    ),
                  ),
                ),
              ),
              Text('$done de $total pasos', style: OffstockType.label.copyWith(fontSize: 13, color: c.inkSoft)),
            ],
          ),
          if (error != null) Text(error!, style: OffstockType.label.copyWith(color: c.danger)),
          TactileButton(label: busy ? 'Guardando…' : 'Guardar producto', onPressed: busy ? null : onSave),
        ],
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      label: photo == null ? 'Tomar foto del producto' : 'Cambiar foto del producto',
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AnimatedSwitcher(
          duration: Motion.base,
          // Default layout loosens constraints; expand so the box fills the 4:3 frame.
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: photo == null
              ? CustomPaint(
                  key: const ValueKey('empty'),
                  painter: _DashedBorder(color: c.accent),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 10,
                    children: [
                      CustomPaint(size: const Size(56, 44), painter: _CameraGlyph(color: c.accent)),
                      Text('Tomar foto', style: OffstockType.heading.copyWith(color: c.accentText)),
                    ],
                  ),
                )
              : ClipRRect(
                  key: ValueKey(photo.hashCode),
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(photo!, fit: BoxFit.cover),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(999)),
                          child: Text('Cambiar foto', style: OffstockType.label.copyWith(color: c.ink)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)).deflate(1);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.06));
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 14) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _CameraGlyph extends CustomPainter {
  const _CameraGlyph({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    final body = RRect.fromLTRBR(0, s.height * 0.2, s.width, s.height, const Radius.circular(8));
    final bump = Path()
      ..moveTo(s.width * 0.3, s.height * 0.2)
      ..lineTo(s.width * 0.38, 0)
      ..lineTo(s.width * 0.62, 0)
      ..lineTo(s.width * 0.7, s.height * 0.2);
    canvas
      ..drawRRect(body.deflate(1.5), stroke)
      ..drawPath(bump, stroke)
      ..drawCircle(Offset(s.width / 2, s.height * 0.6), s.height * 0.22, stroke)
      ..drawCircle(Offset(s.width * 0.84, s.height * 0.36), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CameraGlyph old) => old.color != color;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? c.accent : c.line, width: 1.5),
          boxShadow: [if (selected) BoxShadow(color: c.accentLip, offset: const Offset(0, 3))],
        ),
        child: AnimatedSize(
          duration: Motion.fast,
          child: Text(
            selected ? '✓ $label' : label,
            style: OffstockType.label.copyWith(color: selected ? c.onAccent : c.ink),
          ),
        ),
      ),
    );
  }
}

/// Variant label with a − / number / + counter. The number stays editable for big counts;
/// tapping it selects the whole value so typing replaces the 0 instead of appending to it.
class _CountRow extends StatefulWidget {
  const _CountRow({required this.label, required this.controller, required this.onChanged});

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<_CountRow> createState() => _CountRowState();
}

class _CountRowState extends State<_CountRow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        final c = widget.controller;
        c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final c = widget.controller;
    final next = ((int.tryParse(c.text.trim()) ?? 0) + delta).clamp(0, 99999);
    c.text = '$next';
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final focused = _focus.hasFocus;
    Widget round(String glyph, int delta, String semantic) => Pressable(
          onTap: () => _step(delta),
          scale: 0.85,
          label: semantic,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle, border: Border.all(color: c.line, width: 1.5)),
            child: Text(glyph, style: OffstockType.heading.copyWith(color: c.ink)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        spacing: 8,
        children: [
          Expanded(child: Text(widget.label, style: OffstockType.body.copyWith(color: c.ink))),
          round('−', -1, 'Quitar una pieza de ${widget.label}'),
          AnimatedContainer(
            duration: Motion.fast,
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: focused ? c.accent : c.line, width: focused ? 2 : 1.5),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: OffstockType.price.copyWith(fontSize: 18, color: c.ink),
              cursorColor: c.accent,
              scrollPadding: const EdgeInsets.only(bottom: 140),
              onChanged: (_) => widget.onChanged(),
              decoration: const InputDecoration.collapsed(hintText: '0'),
            ),
          ),
          round('+', 1, 'Agregar una pieza de ${widget.label}'),
        ],
      ),
    );
  }
}

class _NewOptionDialog extends StatefulWidget {
  const _NewOptionDialog({required this.axis});

  final VariantAxis axis;

  @override
  State<_NewOptionDialog> createState() => _NewOptionDialogState();
}

class _NewOptionDialogState extends State<_NewOptionDialog> {
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Dialog(
      backgroundColor: c.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            OffstockField(
              label: 'Nueva opción en ${widget.axis.label.toLowerCase()}',
              controller: _value,
              autofocus: true,
              maxLength: 30,
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
            TactileButton(label: 'Agregar', onPressed: () => Navigator.of(context).pop(_value.text)),
          ],
        ),
      ),
    );
  }
}

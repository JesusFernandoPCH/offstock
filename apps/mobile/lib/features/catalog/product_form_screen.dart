import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/offstock_field.dart';
import '../../core/widgets/tactile_button.dart';
import 'catalog_repo.dart';
import 'templates.dart';

/// New product: photo, basics, the template's variant axes, and pieces on hand per variant.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.template, required this.onSave, required this.takePhoto});

  final CatalogTemplate template;
  final Future<void> Function(ProductDraft draft) onSave;
  final Future<Uint8List?> Function() takePhoto;

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
  Uint8List? _photo;
  bool _busy = false;
  String? _error;

  List<Map<String, String>> get _variants => expandVariants({
        // Keep each axis in option order so "CH, M, G" never shows up as "G, CH, M".
        for (final a in widget.template.axes) a.key: [for (final o in _options[a.key]!) if (_chosen[a.key]!.contains(o)) o],
      });

  TextEditingController _stockFor(Map<String, String> attrs) =>
      _stock.putIfAbsent(jsonEncode(attrs), () => TextEditingController(text: '0'));

  @override
  void dispose() {
    for (final c in [_name, _category, _price, _cost, ..._fields.values, ..._stock.values]) {
      c.dispose();
    }
    super.dispose();
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
    final name = _name.text.trim();
    final price = parsePesos(_price.text);
    final cost = _cost.text.trim().isEmpty ? null : parsePesos(_cost.text);
    final variants = _variants;
    final stocks = [
      for (final v in variants)
        switch (_stockFor(v).text.trim()) { '' => 0, final t => int.tryParse(t) },
    ];

    String? problem;
    if (name.isEmpty) {
      problem = 'Escribe el nombre del producto.';
    } else if (price == null) {
      problem = 'Escribe un precio válido, por ejemplo 249 o 249.50.';
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

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Expanded(child: Text('Nuevo producto', style: OffstockType.title.copyWith(color: c.ink))),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  child: Text('Cancelar', style: OffstockType.label.copyWith(color: c.accentText)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PhotoBox(photo: _photo, onTap: _busy ? null : _pickPhoto),
            const SizedBox(height: 20),
            OffstockField(label: 'Nombre', controller: _name, hint: 'Playera básica cuello redondo', maxLength: 120),
            const SizedBox(height: 16),
            OffstockField(label: 'Categoría', controller: _category, hint: t.categories.first, maxLength: 60),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in t.categories)
                  _Chip(
                    label: cat,
                    selected: _category.text == cat,
                    onTap: () => setState(() => _category.text = cat),
                  ),
              ],
            ),
            for (final f in t.fields) ...[
              const SizedBox(height: 16),
              OffstockField(label: f.label, controller: _fields[f.key]!, maxLength: 60),
            ],
            const SizedBox(height: 16),
            Row(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OffstockField(
                    label: 'Precio de venta',
                    controller: _price,
                    hint: '249.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                Expanded(
                  child: OffstockField(
                    label: 'Costo (solo tú lo ves)',
                    controller: _cost,
                    hint: 'Opcional',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            for (final axis in t.axes) ...[
              const SizedBox(height: 24),
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
            ],
            const SizedBox(height: 24),
            Text(
              variants.length == 1 ? 'Piezas en tienda' : 'Piezas en tienda por variante (${variants.length})',
              style: OffstockType.label.copyWith(color: c.inkSoft),
            ),
            const SizedBox(height: 8),
            for (final v in variants)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Text(v.isEmpty ? 'Todas' : variantLabel(v),
                          style: OffstockType.body.copyWith(color: c.ink)),
                    ),
                    SizedBox(
                      width: 96,
                      child: _CountField(controller: _stockFor(v), label: 'Piezas de ${variantLabel(v)}'),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: OffstockType.label.copyWith(color: c.danger)),
            ],
            const SizedBox(height: 20),
            TactileButton(label: _busy ? 'Guardando…' : 'Guardar producto', onPressed: _busy ? null : _save),
          ],
        ),
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
    return Semantics(
      button: true,
      label: photo == null ? 'Tomar foto del producto' : 'Cambiar foto del producto',
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.line, width: 2),
            ),
            child: photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 6,
                    children: [
                      Text('Tomar foto', style: OffstockType.heading.copyWith(color: c.accentText)),
                      Text('Así la reconocen tus vendedores', style: OffstockType.label.copyWith(color: c.inkSoft)),
                    ],
                  )
                : Stack(
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? c.accent : c.line, width: 1.5),
          ),
          child: Text(label, style: OffstockType.label.copyWith(color: selected ? c.onAccent : c.ink)),
        ),
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: OffstockType.price.copyWith(fontSize: 17, color: c.ink),
          cursorColor: c.accent,
          decoration: const InputDecoration.collapsed(hintText: '0'),
        ),
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

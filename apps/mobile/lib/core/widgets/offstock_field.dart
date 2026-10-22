import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Text input in the Offstock look. The focused field is unmistakable: rosa border, rosa label,
/// a slight lift. Hints are dim and start with "Ej." so they never read as typed values.
class OffstockField extends StatefulWidget {
  const OffstockField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLength,
    this.autofocus = false,
    this.big = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool autofocus;
  final bool big;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OffstockField> createState() => _OffstockFieldState();
}

class _OffstockFieldState extends State<OffstockField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final focused = _focus.hasFocus;
    final style = widget.big
        ? OffstockType.total.copyWith(fontSize: 34, color: c.ink, letterSpacing: 8)
        : OffstockType.body.copyWith(fontSize: 18, color: c.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        AnimatedDefaultTextStyle(
          duration: Motion.fast,
          style: OffstockType.label.copyWith(color: focused ? c.accentText : c.inkSoft),
          child: Text(widget.label),
        ),
        GestureDetector(
          onTap: _focus.requestFocus,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: focused ? c.accent : c.line, width: focused ? 2 : 1.5),
              boxShadow: [
                if (focused) BoxShadow(color: c.accent.withValues(alpha: 0.18), blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              style: style,
              cursorColor: c.accent,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              // Leaves room under the field when the keyboard scrolls it into view.
              scrollPadding: const EdgeInsets.only(bottom: 140),
              inputFormatters: [if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength)],
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: style.copyWith(color: c.inkSoft.withValues(alpha: 0.45)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Text input in the Offstock look: paper card, ink text, rosa cursor.
class OffstockField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final style = big
        ? OffstockType.total.copyWith(fontSize: 34, color: c.ink, letterSpacing: 8)
        : OffstockType.body.copyWith(fontSize: 18, color: c.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(label, style: OffstockType.label.copyWith(color: c.inkSoft)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            style: style,
            cursorColor: c.accent,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            inputFormatters: [if (maxLength != null) LengthLimitingTextInputFormatter(maxLength)],
            decoration: InputDecoration.collapsed(
              hintText: hint,
              hintStyle: style.copyWith(color: c.inkSoft.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ],
    );
  }
}

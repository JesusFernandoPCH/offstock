import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Button with a physical lip that sinks on press, like a cash register key.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _press(bool down) {
    if (_enabled && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final face = widget.secondary ? c.surface : c.accent;
    final lip = widget.secondary ? c.line : c.accentLip;
    final fg = widget.secondary ? c.ink : c.onAccent;
    final lift = _down ? 1.0 : 4.0;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: _enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: _enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: Motion.press,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, 4 - lift, 0),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(16),
              border: widget.secondary ? Border.all(color: c.line) : null,
              boxShadow: [BoxShadow(color: lip, offset: Offset(0, lift))],
            ),
            alignment: Alignment.center,
            child: Text(widget.label, style: OffstockType.label.copyWith(fontSize: 16, color: fg)),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Minimum time the pressed state stays visible, so a quick tap still shows it was heard.
const minPressVisible = Duration(milliseconds: 130);

/// Anything tappable that is not a TactileButton: chips, tiles, tabs, steppers.
/// Shrinks under the finger, springs back, and gives a light haptic tick.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
    this.selected,
    this.label,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool? selected;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  DateTime _downAt = DateTime.now();
  Timer? _hold;

  void _press() {
    if (widget.onTap == null) return;
    _hold?.cancel();
    _downAt = DateTime.now();
    setState(() => _down = true);
  }

  void _release() {
    final left = minPressVisible - DateTime.now().difference(_downAt);
    _hold?.cancel();
    _hold = Timer(left.isNegative ? Duration.zero : left, () {
      if (mounted) setState(() => _down = false);
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: _down ? Motion.press : Motion.base,
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

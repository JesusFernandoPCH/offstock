import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Cart item shaped like a clothing hang tag. Swings from its hole when it first appears.
class HangTag extends StatefulWidget {
  const HangTag({super.key, required this.child, this.swingIn = false});

  final Widget child;
  final bool swingIn;

  @override
  State<HangTag> createState() => _HangTagState();
}

class _HangTagState extends State<HangTag> with SingleTickerProviderStateMixin {
  static const _hole = Offset(14, 0); // pivot, relative to the left-center edge

  late final _ctrl = AnimationController(vsync: this, duration: Motion.swing);

  // Same keyframes as the web preview: drop, overshoot, settle.
  static final _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: -14.0, end: 9.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 9.0, end: -5.0), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -5.0, end: 2.0), weight: 23),
    TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 22),
  ]);
  static final _drop = Tween(begin: -22.0, end: 0.0)
      .chain(CurveTween(curve: const Interval(0, 0.3, curve: Curves.easeOut)));
  static final _fade = CurveTween(curve: const Interval(0, 0.3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.swingIn || MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1;
    } else if (_ctrl.isDismissed) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final tag = PhysicalShape(
      clipper: const _TagClipper(),
      color: c.surface,
      elevation: 4,
      shadowColor: c.shadow.withValues(alpha: 0.35),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 12, 12, 12),
            child: widget.child,
          ),
          Positioned(
            left: 9,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _ctrl,
      child: tag,
      builder: (context, child) => Opacity(
        opacity: _fade.evaluate(_ctrl),
        child: Transform.translate(
          offset: Offset(0, _drop.evaluate(_ctrl)),
          child: Transform.rotate(
            angle: _angle.evaluate(_ctrl) * math.pi / 180,
            alignment: Alignment.centerLeft,
            origin: _hole,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TagClipper extends CustomClipper<Path> {
  const _TagClipper();

  @override
  Path getClip(Size s) {
    const cut = 14.0, r = 14.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(s.width - r, 0)
      ..arcToPoint(Offset(s.width, r), radius: const Radius.circular(r))
      ..lineTo(s.width, s.height - r)
      ..arcToPoint(Offset(s.width - r, s.height), radius: const Radius.circular(r))
      ..lineTo(cut, s.height)
      ..lineTo(0, s.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_TagClipper oldClipper) => false;
}

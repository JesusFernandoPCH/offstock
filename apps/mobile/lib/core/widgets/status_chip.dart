import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

enum ChipKind { ok, hold, danger, muted }

/// Stock / sync state. State is shown by shape and color, not only by text.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.kind});

  final String label;
  final ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final c = OffstockColors.of(context);
    final (fg, bg) = switch (kind) {
      ChipKind.ok => (c.ok, c.ok.withValues(alpha: 0.14)),
      ChipKind.hold => (c.onHold, c.hold),
      ChipKind.danger => (c.danger, c.danger.withValues(alpha: 0.14)),
      ChipKind.muted => (c.inkSoft, const Color(0x00000000)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: kind == ChipKind.muted ? Border.all(color: c.inkSoft) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: OffstockType.label.copyWith(fontSize: 13, color: fg)),
        ],
      ),
    );
  }
}

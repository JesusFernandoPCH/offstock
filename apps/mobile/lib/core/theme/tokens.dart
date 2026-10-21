import 'package:flutter/widgets.dart';

/// Mirror of design/tokens.json. test/tokens_test.dart fails if they drift.
class OffstockColors {
  const OffstockColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentLip,
    required this.accentText,
    required this.onAccent,
    required this.hold,
    required this.onHold,
    required this.ok,
    required this.danger,
    required this.line,
    required this.shadow,
  });

  final Color bg, surface, ink, inkSoft, accent, accentLip, accentText, onAccent;
  final Color hold, onHold, ok, danger, line, shadow;

  static const light = OffstockColors(
    bg: Color(0xFFFAF5F2),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF2B1630),
    inkSoft: Color(0xFF6E5A70),
    accent: Color(0xFFE4007C),
    accentLip: Color(0xFFA3005A),
    accentText: Color(0xFFC4006A),
    onAccent: Color(0xFFFFFFFF),
    hold: Color(0xFFF2A007),
    onHold: Color(0xFF2B1630),
    ok: Color(0xFF1F7A55),
    danger: Color(0xFFC2311A),
    line: Color(0xFFEADFE3),
    shadow: Color(0xFF5A2A4A),
  );

  static const dark = OffstockColors(
    bg: Color(0xFF1C1220),
    surface: Color(0xFF2A1C2F),
    ink: Color(0xFFF6ECF2),
    inkSoft: Color(0xFFBFA9C2),
    accent: Color(0xFFFF4FA3),
    accentLip: Color(0xFFB8126A),
    accentText: Color(0xFFFF4FA3),
    onAccent: Color(0xFF1C1220),
    hold: Color(0xFFFFB835),
    onHold: Color(0xFF1C1220),
    ok: Color(0xFF4CC38A),
    danger: Color(0xFFFF6B57),
    line: Color(0xFF3D2B42),
    shadow: Color(0xFF000000),
  );

  static OffstockColors of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? dark : light;

  Map<String, Color> toMap() => {
        'bg': bg,
        'surface': surface,
        'ink': ink,
        'inkSoft': inkSoft,
        'accent': accent,
        'accentLip': accentLip,
        'accentText': accentText,
        'onAccent': onAccent,
        'hold': hold,
        'onHold': onHold,
        'ok': ok,
        'danger': danger,
        'line': line,
        'shadow': shadow,
      };
}

abstract final class Motion {
  static const press = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 320);
  static const swing = Duration(milliseconds: 620);
}

/// Bricolage Grotesque is variable: weight, width and optical size come from axes.
abstract final class OffstockType {
  static const family = 'Bricolage';

  static TextStyle _style(double size, double wght, double opsz,
          {double wdth = 100, double? height, bool tabular = false}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: height,
        fontVariations: [
          FontVariation('wght', wght),
          FontVariation('opsz', opsz),
          FontVariation('wdth', wdth),
        ],
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  static final total = _style(44, 800, 96, wdth: 88, height: 1, tabular: true);
  static final title = _style(28, 700, 48, wdth: 92, height: 1.1);
  static final heading = _style(20, 650, 24, height: 1.2);
  static final body = _style(16, 420, 14, height: 1.5);
  static final label = _style(14, 560, 12);
  static final price = _style(15, 700, 14, tabular: true);
  static final caption = _style(12, 500, 12, tabular: true);
}

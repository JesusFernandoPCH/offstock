import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/theme/tokens.dart';

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void main() {
  final json = jsonDecode(File('../../design/tokens.json').readAsStringSync()) as Map<String, dynamic>;
  final colors = json['color'] as Map<String, dynamic>;

  for (final (theme, dart) in [('light', OffstockColors.light), ('dark', OffstockColors.dark)]) {
    test('$theme colors match design/tokens.json', () {
      final source = colors[theme] as Map<String, dynamic>;
      final mirror = dart.toMap();
      expect(mirror.keys.toSet(), source.keys.toSet());
      for (final key in source.keys) {
        expect(_hex(mirror[key]!), (source[key]['value'] as String).toUpperCase(), reason: '$theme.$key');
      }
    });
  }
}

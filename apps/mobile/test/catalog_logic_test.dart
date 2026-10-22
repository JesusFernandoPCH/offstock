import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/money.dart';
import 'package:offstock/features/catalog/templates.dart';

void main() {
  test('expandVariants multiplies chosen values and skips empty axes', () {
    expect(expandVariants({}), [<String, String>{}]);
    expect(expandVariants({'talla': [], 'color': []}), [<String, String>{}]);
    expect(expandVariants({'talla': ['M'], 'color': []}), [
      {'talla': 'M'},
    ]);
    final grid = expandVariants({
      'talla': ['CH', 'M', 'G', 'EG'],
      'color': ['Negro', 'Blanco', 'Gris'],
    });
    expect(grid.length, 12);
    expect(grid.first, {'talla': 'CH', 'color': 'Negro'});
    expect(grid.last, {'talla': 'EG', 'color': 'Gris'});
    expect(grid.toSet().length, 12, reason: 'no duplicates');
  });

  test('every business type has a template; unknown falls back to other', () {
    for (final type in ['clothing', 'food', 'tech', 'other']) {
      expect(catalogTemplates.containsKey(type), isTrue);
    }
    expect(templateFor('spaceships'), same(catalogTemplates['other']));
  });

  test('parsePesos turns typed prices into cents', () {
    expect(parsePesos('249'), 24900);
    expect(parsePesos(r' $1,249.5 '), 124950);
    expect(parsePesos('99.90'), 9990);
    expect(parsePesos('0'), 0);
    expect(parsePesos(''), isNull);
    expect(parsePesos('-5'), isNull);
    expect(parsePesos('12.345'), isNull);
    expect(parsePesos('abc'), isNull);
  });
}

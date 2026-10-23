import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/theme/tokens.dart';
import 'package:offstock/features/catalog/catalog_repo.dart';
import 'package:offstock/features/catalog/catalog_screen.dart';
import 'package:offstock/features/catalog/product_form_screen.dart';
import 'package:offstock/features/catalog/scanner_screen.dart';
import 'package:offstock/features/catalog/templates.dart';
import 'package:offstock/main.dart';

Widget _app(Widget home) => MaterialApp(
      theme: offstockTheme(OffstockColors.light, Brightness.light),
      builder: offstockSurface,
      home: home,
    );

const _shirt = CatalogItem(
  productId: 'p1',
  name: 'Playera básica',
  category: 'Playeras',
  variants: [
    VariantRow(id: 'v1', attrs: {'talla': 'M'}, priceCents: 24900, onHand: 3, barcode: '7501234500018'),
    VariantRow(id: 'v2', attrs: {'talla': 'G'}, priceCents: 26900, onHand: 2),
  ],
);
const _cap = CatalogItem(
  productId: 'p2',
  name: 'Gorra',
  variants: [VariantRow(id: 'v3', attrs: {}, priceCents: 29900, onHand: 0)],
);

/// The form is a long scrolling list; a tall test screen builds all of it.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('empty catalog invites the owner to add the first product', (tester) async {
    var adds = 0;
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [], onAdd: ({barcode}) async => adds++ > 99)));
    await tester.pumpAndSettle();
    expect(find.text('Tu catálogo está vacío.'), findsOneWidget);
    await tester.tap(find.text('Agregar producto'));
    expect(adds, 1);
  });

  testWidgets('employees see an empty catalog without an add button', (tester) async {
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [])));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay productos.'), findsOneWidget);
    expect(find.text('Agregar producto'), findsNothing);
  });

  testWidgets('catalog lists stock, price range, and searches by name or barcode', (tester) async {
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [_shirt, _cap])));
    await tester.pumpAndSettle();
    expect(find.text('5 en tienda'), findsOneWidget);
    expect(find.text(r'desde $249.00'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gorra');
    await tester.pump();
    expect(find.text('Playera básica'), findsNothing);
    expect(find.text('Gorra'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '7501234500018');
    await tester.pump();
    expect(find.text('Playera básica'), findsOneWidget);
    expect(find.text('Gorra'), findsNothing);
  });

  testWidgets('load failure offers a retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(CatalogScreen(load: () async {
      if (calls++ == 0) throw Exception('offline');
      return [_cap];
    })));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar el catálogo.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Gorra'), findsOneWidget);
  });

  testWidgets('clothing form multiplies sizes × colors and saves stock per variant', (tester) async {
    ProductDraft? saved;
    _tall(tester);
    await tester.pumpWidget(_app(ProductFormScreen(
      template: catalogTemplates['clothing']!,
      onSave: (d) async => saved = d,
      takePhoto: () async => Uint8List(0),
    )));

    Future<void> type(String hint, String text) => tester.enterText(find.widgetWithText(TextField, hint), text);

    await type('Ej. Playera básica cuello redondo', 'Playera básica');
    await type('Ej. 249', '249.50');
    await type('Opcional', '110');
    for (final chip in ['M', 'G', 'Negro', 'Blanco']) {
      await tester.tap(find.text(chip));
    }
    await tester.pump();
    expect(find.textContaining('4 variantes'), findsOneWidget);
    expect(find.text('0 de 4 pasos'), findsNothing, reason: 'name, price and sizes already count');

    await tester.enterText(
      find.descendant(of: find.widgetWithText(Row, 'M, Negro'), matching: find.byType(TextField)),
      '5',
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Playera básica');
    expect(saved!.variants.length, 4);
    final first = saved!.variants.first;
    expect(first.attrs, {'talla': 'M', 'color': 'Negro'});
    expect((first.priceCents, first.costCents, first.stock), (24950, 11000, 5));
    expect(saved!.variants.skip(1).every((v) => v.stock == 0), isTrue);
  });

  testWidgets('form explains what is missing instead of saving', (tester) async {
    var saves = 0;
    _tall(tester);
    await tester.pumpWidget(_app(ProductFormScreen(
      template: catalogTemplates['other']!,
      onSave: (_) async => saves++,
      takePhoto: () async => null,
    )));
    await tester.tap(find.text('Guardar producto'));
    await tester.pump();
    expect(find.text('Escribe el nombre del producto (paso 2).'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('first-time guide shows once and steps turn into checks', (tester) async {
    var seen = 0;
    _tall(tester);
    await tester.pumpWidget(_app(ProductFormScreen(
      template: catalogTemplates['other']!,
      onSave: (_) async {},
      takePhoto: () async => null,
      showGuide: true,
      onGuideSeen: () => seen++,
    )));
    expect(find.text('Tu primer producto'), findsOneWidget);
    expect(find.text('0 de 3 pasos'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ej. Playera básica cuello redondo'), 'Gorra');
    await tester.enterText(find.widgetWithText(TextField, 'Ej. 249'), '299');
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3 pasos'), findsOneWidget);
    expect(find.text('✓'), findsNWidgets(2));

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Tu primer producto'), findsNothing);
    expect(seen, 1);
  });

  test('only 8–14 digit retail codes are accepted', () {
    expect(acceptBarcode(' 7501234500018 '), '7501234500018');
    expect(acceptBarcode('12345678'), '12345678');
    expect(acceptBarcode('1234567'), isNull);
    expect(acceptBarcode('ABC12345678'), isNull);
    expect(acceptBarcode(null), isNull);
  });

  testWidgets('scanning a known code filters to its product', (tester) async {
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [_shirt, _cap], scan: () async => '7501234500018')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Escanear código de barras'));
    await tester.pumpAndSettle();
    expect(find.text('Playera básica'), findsOneWidget);
    expect(find.text('Gorra'), findsNothing);
  });

  testWidgets('scanning an unknown code lets the owner create it with that code', (tester) async {
    String? created;
    await tester.pumpWidget(_app(CatalogScreen(
      load: () async => [_cap],
      scan: () async => '7509999999990',
      onAdd: ({barcode}) async {
        created = barcode;
        return false;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Escanear código de barras'));
    await tester.pumpAndSettle();
    expect(find.text('El código 7509999999990 no está en tu catálogo.'), findsOneWidget);
    await tester.tap(find.text('Crear producto con este código'));
    expect(created, '7509999999990');
  });

  testWidgets('employees are told to ask the owner about unknown codes', (tester) async {
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [_cap], scan: () async => '7509999999990')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Escanear código de barras'));
    await tester.pumpAndSettle();
    expect(find.text('Pídele al dueño del negocio que lo agregue.'), findsOneWidget);
    expect(find.text('Crear producto con este código'), findsNothing);
  });

  testWidgets('prefilled code goes to the first variant; others scan their own, no repeats', (tester) async {
    ProductDraft? saved;
    var next = '7500000000017';
    _tall(tester);
    await tester.pumpWidget(_app(ProductFormScreen(
      template: catalogTemplates['clothing']!,
      onSave: (d) async => saved = d,
      takePhoto: () async => null,
      barcode: '7509999999990',
      scan: () async => next,
    )));
    await tester.enterText(find.widgetWithText(TextField, 'Ej. Playera básica cuello redondo'), 'Playera');
    await tester.enterText(find.widgetWithText(TextField, 'Ej. 249'), '249');
    await tester.tap(find.text('M'));
    await tester.tap(find.text('G'));
    await tester.pump();
    expect(find.text('7509999999990'), findsOneWidget);

    next = '7509999999990';
    await tester.tap(find.text('Escanear código'));
    await tester.pump();
    await tester.tap(find.text('Guardar producto'));
    await tester.pump();
    expect(find.textContaining('mismo código'), findsOneWidget);
    expect(saved, isNull);

    await tester.tap(find.text('Quitar').last);
    await tester.pump();
    next = '7500000000017';
    await tester.tap(find.text('Escanear código'));
    await tester.pump();
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    expect([for (final v in saved!.variants) v.barcode], ['7509999999990', '7500000000017']);
  });
}

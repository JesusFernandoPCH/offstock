import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/theme/tokens.dart';
import 'package:offstock/features/catalog/catalog_repo.dart';
import 'package:offstock/features/catalog/catalog_screen.dart';
import 'package:offstock/features/catalog/product_form_screen.dart';
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
    await tester.pumpWidget(_app(CatalogScreen(load: () async => [], onAdd: () async => adds++ > 99)));
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

    await type('Playera básica cuello redondo', 'Playera básica');
    await type('249.00', '249.50');
    await type('Opcional', '110');
    for (final chip in ['M', 'G', 'Negro', 'Blanco']) {
      await tester.tap(find.text(chip));
    }
    await tester.pump();
    expect(find.text('Piezas en tienda por variante (4)'), findsOneWidget);

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
    expect(find.text('Escribe el nombre del producto.'), findsOneWidget);
    expect(saves, 0);
  });
}

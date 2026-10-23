import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/theme/tokens.dart';
import 'package:offstock/features/catalog/catalog_repo.dart';
import 'package:offstock/features/catalog/labels_pdf.dart';
import 'package:offstock/features/catalog/labels_screen.dart';
import 'package:offstock/main.dart';

int _pages(Uint8List pdf) => RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(pdf)).length;

const _shirt = CatalogItem(
  productId: 'p1',
  name: 'Playera básica',
  variants: [
    VariantRow(id: 'v1', attrs: {'talla': 'M'}, priceCents: 24900, onHand: 3, barcode: '2000000000015'),
    VariantRow(id: 'v2', attrs: {'talla': 'G'}, priceCents: 24900, onHand: 0, barcode: '2000000000022'),
  ],
);

void main() {
  test('symbology follows the code, falling back to Code 128', () {
    expect(symbologyFor('4006381333931').name, 'EAN 13');
    expect(symbologyFor('96385074').name, 'EAN 8');
    expect(symbologyFor('4006381333932').name, 'CODE 128', reason: 'bad check digit');
  });

  test('one label per copy, 24 per letter page', () async {
    LabelSpec spec(int copies) =>
        LabelSpec(name: 'Playera', variant: 'M', priceCents: 24900, barcode: '4006381333931', copies: copies);
    expect(_pages(await buildLabelsPdf([spec(24)])), 1);
    expect(_pages(await buildLabelsPdf([spec(20), spec(5)])), 2);
  });

  testWidgets('labels default to pieces in stock and print the sheet', (tester) async {
    Uint8List? printed;
    bool? shared;
    await tester.pumpWidget(MaterialApp(
      theme: offstockTheme(OffstockColors.light, Brightness.light),
      builder: offstockSurface,
      home: LabelsScreen(
        item: _shirt,
        output: (pdf, {required share}) async {
          printed = pdf;
          shared = share;
        },
      ),
    ));
    expect(find.text('3 etiquetas en 1 hoja tamaño carta.'), findsOneWidget);

    await tester.tap(find.text('+').last);
    await tester.pump();
    expect(find.text('4 etiquetas en 1 hoja tamaño carta.'), findsOneWidget);

    await tester.tap(find.text('Imprimir'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    expect(shared, isFalse);
    expect(_pages(printed!), 1);
  });
}

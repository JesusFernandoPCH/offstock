import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/widgets/tactile_button.dart';
import 'package:offstock/main.dart';

void main() {
  testWidgets('TactileButton fires only when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        TactileButton(label: 'Cobrar', onPressed: () => taps++),
        const TactileButton(label: 'Bloqueado', onPressed: null),
      ]),
    ));
    await tester.tap(find.text('Cobrar'));
    await tester.tap(find.text('Bloqueado'));
    expect(taps, 1);
  });

  testWidgets('scanning adds a hang tag and updates the total', (tester) async {
    await tester.pumpWidget(const OffstockApp());
    expect(find.text('Escanea una prenda para empezar la venta.'), findsOneWidget);

    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();
    expect(find.text('Playera básica cuello redondo'), findsOneWidget);
    expect(find.text(r'$249.00'), findsNWidgets(2)); // tag price + total

    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(find.text('Escanea una prenda para empezar la venta.'), findsOneWidget);
  });
}

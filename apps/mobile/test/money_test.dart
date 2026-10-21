import 'package:flutter_test/flutter_test.dart';
import 'package:offstock/core/money.dart';

void main() {
  test('formats integer cents as MXN', () {
    expect(formatMxn(0), r'$0.00');
    expect(formatMxn(5), r'$0.05');
    expect(formatMxn(99900), r'$999.00');
    expect(formatMxn(184700), r'$1,847.00');
    expect(formatMxn(123456789), r'$1,234,567.89');
    expect(formatMxn(-500), r'-$5.00');
  });
}

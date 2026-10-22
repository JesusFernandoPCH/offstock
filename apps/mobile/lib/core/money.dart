/// Formats integer cents as MXN: 184700 -> "$1,847.00". Money never touches doubles.
String formatMxn(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final pesos = (abs ~/ 100).toString();
  final centavos = (abs % 100).toString().padLeft(2, '0');
  final grouped = pesos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign\$$grouped.$centavos';
}

/// Parses what a person types as a price ("249", "1,249.5", "$99.90") into cents.
/// Returns null for anything that is not a non-negative amount with at most 2 decimals.
int? parsePesos(String input) {
  final s = input.trim().replaceAll(RegExp(r'[\s$,]'), '');
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  return int.parse(m[1]!) * 100 + int.parse((m[2] ?? '0').padRight(2, '0'));
}

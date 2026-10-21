/// Formats integer cents as MXN: 184700 -> "$1,847.00". Money never touches doubles.
String formatMxn(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final pesos = (abs ~/ 100).toString();
  final centavos = (abs % 100).toString().padLeft(2, '0');
  final grouped = pesos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign\$$grouped.$centavos';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/tactile_button.dart';

/// Retail barcodes the variants table accepts (8–14 digits); anything else is ignored.
String? acceptBarcode(String? raw) {
  final v = raw?.trim();
  return v != null && RegExp(r'^\d{8,14}$').hasMatch(v) ? v : null;
}

/// Full-screen camera that pops with the first valid code it reads.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _done = false;

  @override
  void dispose() {
    _sweep.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = acceptBarcode(b.rawValue);
      if (code != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = OffstockColors.dark; // camera views read best on dark chrome in either theme
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      color: c.bg,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth * 0.78;
        final window = Rect.fromCenter(center: box.biggest.center(Offset.zero).translate(0, -24), width: w, height: w * 0.62);
        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              scanWindow: window,
              onDetect: _onDetect,
              errorBuilder: (_, error) => _CameraError(denied: error.errorCode == MobileScannerErrorCode.permissionDenied),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (_, _) => CustomPaint(
                  painter: _Frame(window: window, sweep: reduceMotion ? null : _sweep.value, color: c.accent),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: window.bottom + 24,
              child: Text(
                'Apunta al código de barras de la etiqueta.',
                textAlign: TextAlign.center,
                style: OffstockType.body.copyWith(color: c.ink),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Round(label: 'Cerrar', onTap: () => Navigator.of(context).pop()),
                    ValueListenableBuilder(
                      valueListenable: _camera,
                      builder: (_, state, _) => state.torchState == TorchState.unavailable || !state.isRunning
                          ? const SizedBox.shrink()
                          : _Round(
                              label: state.torchState == TorchState.on ? 'Apagar luz' : 'Luz',
                              selected: state.torchState == TorchState.on,
                              onTap: _camera.toggleTorch,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    const c = OffstockColors.dark;
    return Pressable(
      onTap: onTap,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.bg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label, style: OffstockType.label.copyWith(fontSize: 15, color: selected ? c.onAccent : c.ink)),
      ),
    );
  }
}

/// Dims everything outside the scan window, draws its corners, and sweeps a line through it.
class _Frame extends CustomPainter {
  const _Frame({required this.window, required this.sweep, required this.color});

  final Rect window;
  final double? sweep;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(20));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = const Color(0xB31C1220),
    );

    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const arm = 28.0;
    final r = window;
    for (final (p, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy + dy * arm)
          ..lineTo(p.dx, p.dy + dy * 8)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + dx * 8, p.dy)
          ..lineTo(p.dx + dx * arm, p.dy),
        corner,
      );
    }

    if (sweep != null) {
      final y = r.top + 14 + (r.height - 28) * Curves.easeInOut.transform(sweep!);
      canvas.drawLine(
        Offset(r.left + 16, y),
        Offset(r.right - 16, y),
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Frame old) => old.sweep != sweep || old.window != window;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    const c = OffstockColors.dark;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                denied ? 'Offstock no tiene permiso de usar la cámara.' : 'No pudimos abrir la cámara.',
                style: OffstockType.heading.copyWith(color: c.ink),
              ),
              Text(
                denied
                    ? 'Actívalo en Ajustes, Apps, Offstock, Permisos. Mientras tanto puedes escribir el código en la búsqueda.'
                    : 'Cierra esta pantalla e inténtalo otra vez. También puedes escribir el código en la búsqueda.',
                style: OffstockType.body.copyWith(color: c.inkSoft),
              ),
              const SizedBox(height: 8),
              TactileButton(label: 'Volver', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

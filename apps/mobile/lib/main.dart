import 'package:flutter/material.dart';

import 'core/theme/tokens.dart';
import 'core/widgets/gallery_screen.dart';

void main() => runApp(const OffstockApp());

/// MaterialApp is plumbing only (routing, localization, a11y). Every visible component is our own.
class OffstockApp extends StatelessWidget {
  const OffstockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offstock',
      debugShowCheckedModeBanner: false,
      theme: _theme(OffstockColors.light, Brightness.light),
      darkTheme: _theme(OffstockColors.dark, Brightness.dark),
      builder: (context, child) => DefaultTextStyle(
        style: OffstockType.body.copyWith(color: OffstockColors.of(context).ink),
        child: child!,
      ),
      home: const GalleryScreen(),
    );
  }

  static ThemeData _theme(OffstockColors c, Brightness b) => ThemeData(
        brightness: b,
        fontFamily: OffstockType.family,
        scaffoldBackgroundColor: c.bg,
        splashFactory: NoSplash.splashFactory,
        colorScheme: ColorScheme(
          brightness: b,
          primary: c.accent,
          onPrimary: c.onAccent,
          secondary: c.hold,
          onSecondary: c.onHold,
          error: c.danger,
          onError: c.surface,
          surface: c.surface,
          onSurface: c.ink,
        ),
      );
}

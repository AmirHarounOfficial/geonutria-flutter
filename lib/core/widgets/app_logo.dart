import 'package:flutter/material.dart';

/// The GeoNutria brand mark. Renders `assets/icon/app_icon.png` when present,
/// falling back to a styled leaf glyph if the asset hasn't been added yet, so
/// the app always builds and looks intentional.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  static const Color brandTeal = Color(0xFF15596A);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/app_icon.png',
      height: size,
      width: size,
      errorBuilder: (context, error, stack) => Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: brandTeal,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.eco, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

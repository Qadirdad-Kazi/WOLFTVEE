import 'package:flutter/material.dart';

/// WOLFTVEE brand palette — flat, predatory, acid lime.
abstract final class WolfColors {
  static const voidBlack = Color(0xFF070708);
  static const charcoal = Color(0xFF0E0F12);
  static const slate = Color(0xFF16181E);
  static const steel = Color(0xFF22252E);
  static const mist = Color(0xFF9AA0AE);
  static const bone = Color(0xFFF2F3F5);
  static const lime = Color(0xFFC8FF00);
  static const limeDim = Color(0xFF8FB300);
  static const ember = Color(0xFFE23D28);
  static const wolfEye = Color(0xFFFFF3A0);

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00070708),
      Color(0xCC070708),
      Color(0xFF070708),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const scanGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0x00C8FF00),
      Color(0x99C8FF00),
      Color(0x00C8FF00),
    ],
  );
}

import 'package:flutter/animation.dart';

/// Shared motion tokens — predatory, snappy, not bouncy-toy.
abstract final class WolfMotion {
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 420);
  static const Duration slow = Duration(milliseconds: 720);
  static const Duration scan = Duration(milliseconds: 2400);

  static const Curve sharpen = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve hunt = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Curve strike = Cubic(0.4, 0.0, 0.2, 1.0);
}

import 'package:flutter/material.dart';

import '../motion/wolf_motion.dart';
import '../theme/wolf_colors.dart';

/// Horizontal lime scan line — signature WOLFTVEE motion.
class ScanLine extends StatefulWidget {
  const ScanLine({super.key, this.height = 2});

  final double height;

  @override
  State<ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: WolfMotion.scan)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final x = (_c.value * (w + 120)) - 60;
            return SizedBox(
              height: widget.height,
              width: w,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(color: WolfColors.steel.withValues(alpha: 0.35)),
                  Positioned(
                    left: x,
                    width: 96,
                    top: 0,
                    bottom: 0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: WolfColors.scanGradient),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class WolfEyePulse extends StatefulWidget {
  const WolfEyePulse({super.key, this.size = 10});

  final double size;

  @override
  State<WolfEyePulse> createState() => _WolfEyePulseState();
}

class _WolfEyePulseState extends State<WolfEyePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.size,
          height: widget.size * (0.55 + t * 0.45),
          decoration: BoxDecoration(
            color: Color.lerp(WolfColors.lime, WolfColors.wolfEye, t),
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(
                color: WolfColors.lime.withValues(alpha: 0.35 + t * 0.35),
                blurRadius: 8 + t * 6,
              ),
            ],
          ),
        );
      },
    );
  }
}

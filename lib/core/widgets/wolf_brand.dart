import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/wolf_colors.dart';
import 'scan_line.dart';

/// Brand asset path for the official wolf mark.
abstract final class WolfBrandAssets {
  static const logo = 'assets/brand/wolf_logo.jpeg';
}

class WolfBrandMark extends StatelessWidget {
  const WolfBrandMark({
    super.key,
    this.compact = false,
    this.showScan = true,
  });

  final bool compact;
  final bool showScan;

  @override
  Widget build(BuildContext context) {
    final letter = GoogleFonts.bebasNeue(
      color: WolfColors.bone,
      fontSize: compact ? 22 : 34,
      letterSpacing: compact ? 3.2 : 5.5,
      height: 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WolfLogoMark(size: compact ? 28 : 36),
            SizedBox(width: compact ? 8 : 12),
            Text('W O L F T V E E', style: letter),
            const SizedBox(width: 8),
            WolfEyePulse(size: compact ? 7 : 10),
          ],
        ),
        if (showScan) ...[
          const SizedBox(height: 8),
          const SizedBox(width: 220, child: ScanLine(height: 2)),
        ],
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideX(begin: -0.04, curve: Curves.easeOutCubic);
  }
}

/// Official wolf logo mark (app icon artwork).
class WolfLogoMark extends StatelessWidget {
  const WolfLogoMark({
    super.key,
    this.size = 28,
    this.radius = 6,
  });

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        WolfBrandAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => WolfMonogram(size: size),
      ),
    );
  }
}

/// Legacy geometric monogram — kept as fallback if asset fails.
class WolfMonogram extends StatelessWidget {
  const WolfMonogram({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WolfMonogramPainter(),
    );
  }
}

class _WolfMonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = WolfColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeJoin = StrokeJoin.miter;

    final fill = Paint()..color = WolfColors.voidBlack;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.28)
      ..lineTo(size.width * 0.32, size.height * 0.08)
      ..lineTo(size.width * 0.5, size.height * 0.34)
      ..lineTo(size.width * 0.68, size.height * 0.08)
      ..lineTo(size.width * 0.92, size.height * 0.28)
      ..lineTo(size.width * 0.92, size.height * 0.92)
      ..lineTo(size.width * 0.72, size.height * 0.92)
      ..lineTo(size.width * 0.72, size.height * 0.48)
      ..lineTo(size.width * 0.5, size.height * 0.68)
      ..lineTo(size.width * 0.28, size.height * 0.48)
      ..lineTo(size.width * 0.28, size.height * 0.92)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    final fang = Path()
      ..moveTo(size.width * 0.42, size.height * 0.78)
      ..lineTo(size.width * 0.5, size.height * 0.96)
      ..lineTo(size.width * 0.58, size.height * 0.78);
    canvas.drawPath(fang, Paint()..color = WolfColors.ember);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/wolf_colors.dart';
import 'scan_line.dart';

/// Brand asset paths — official wolf logo mark.
abstract final class WolfBrandAssets {
  /// White geometric wolf head + wordmark artwork.
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

/// Official wolf app-icon mark used in navbar, splash, about, hero, etc.
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
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: WolfColors.voidBlack,
          alignment: Alignment.center,
          child: Icon(
            Icons.pets,
            size: size * 0.55,
            color: WolfColors.lime,
          ),
        ),
      ),
    );
  }
}

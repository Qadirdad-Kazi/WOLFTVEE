import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/wolf_brand.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: WolfColors.voidBlack),
          CustomPaint(painter: _GridPainter()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WolfLogoMark(size: 148, radius: 18)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.72, 0.72),
                      duration: 700.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .then()
                    .shimmer(
                      duration: 1400.ms,
                      color: WolfColors.lime.withValues(alpha: 0.35),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.04, 1.04),
                      duration: 1100.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 28),
                Text(
                  'W O L F T V E E',
                  style: Theme.of(context).textTheme.displaySmall,
                ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.18),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 200,
                  child: ScanLine(height: 2),
                )
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideX(begin: -0.2),
                const SizedBox(height: 20),
                Text(
                  'LOCKING ONTO THE PACK',
                  style: Theme.of(context).textTheme.labelMedium,
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
                      begin: 0.35,
                      end: 1,
                      duration: 900.ms,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = WolfColors.steel.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 42.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

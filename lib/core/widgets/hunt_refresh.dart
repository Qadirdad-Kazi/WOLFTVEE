import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion/wolf_motion.dart';
import '../theme/wolf_colors.dart';
import 'scan_line.dart';
import 'tv_focusable.dart';

/// Lime hunt-sweep overlay — one full wipe, then content swaps live.
class HuntSweepOverlay extends StatefulWidget {
  const HuntSweepOverlay({
    super.key,
    required this.active,
    this.status = 'SWITCHING SIGNAL',
  });

  final bool active;
  final String status;

  @override
  State<HuntSweepOverlay> createState() => _HuntSweepOverlayState();
}

class _HuntSweepOverlayState extends State<HuntSweepOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant HuntSweepOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && _c.isDismissed) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final wipe = t < 0.55 ? (t / 0.55) : 1.0;
          final fade = t < 0.55 ? 1.0 : 1.0 - ((t - 0.55) / 0.45);

          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: WolfColors.voidBlack.withValues(alpha: 0.72)),
                ClipPath(
                  clipper: _SweepClipper(wipe),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF0E0F12),
                          Color(0xFF1A2200),
                          Color(0xFFC8FF00),
                        ],
                        stops: [0.0, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(-1 + wipe * 2, 0),
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: WolfColors.lime,
                      boxShadow: [
                        BoxShadow(
                          color: WolfColors.lime.withValues(alpha: 0.85),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'WOLFTVEE',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(width: 200, child: ScanLine(height: 2)),
                      const SizedBox(height: 14),
                      Text(
                        widget.status,
                        style: Theme.of(context).textTheme.labelMedium,
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fade(begin: 0.4, end: 1, duration: 500.ms),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SweepClipper extends CustomClipper<Path> {
  _SweepClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
  }

  @override
  bool shouldReclip(covariant _SweepClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Flat refresh control with spin + lime strike.
class HuntRefreshButton extends StatefulWidget {
  const HuntRefreshButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;

  @override
  State<HuntRefreshButton> createState() => _HuntRefreshButtonState();
}

class _HuntRefreshButtonState extends State<HuntRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant HuntRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && !oldWidget.busy) {
      _spin.repeat();
    } else if (!widget.busy && oldWidget.busy) {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WolfTvFocusable(
      enabled: !widget.busy,
      onActivate: widget.busy ? null : widget.onPressed,
      child: Material(
        color: WolfColors.lime,
        child: InkWell(
          onTap: widget.busy ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: WolfMotion.fast,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 14,
              vertical: widget.compact ? 10 : 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _spin,
                  child: Icon(
                    Icons.sync,
                    size: widget.compact ? 18 : 20,
                    color: WolfColors.voidBlack,
                  ),
                ),
                if (!widget.compact) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.busy ? 'HUNTING' : 'REFRESH',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: WolfColors.voidBlack,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cross-fades / slides catalog content when data generation changes.
class LiveCatalogSwitch extends StatelessWidget {
  const LiveCatalogSwitch({
    super.key,
    required this.generation,
    required this.child,
  });

  final Object generation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: WolfMotion.medium,
      switchInCurve: WolfMotion.hunt,
      switchOutCurve: WolfMotion.strike,
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0.04, 0.06),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(generation),
        child: child,
      ),
    );
  }
}

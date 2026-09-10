import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/models/media_item.dart';
import '../config/env.dart';
import '../theme/wolf_colors.dart';
import 'scan_line.dart';
import 'tv_focusable.dart';
import 'wolf_brand.dart';

/// Full-bleed hero carousel — auto-advances featured titles with soft motion.
class WolfHeroBanner extends StatefulWidget {
  const WolfHeroBanner({
    super.key,
    required this.items,
    required this.onWatch,
    required this.onBrowse,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item) onWatch;
  final VoidCallback onBrowse;

  @override
  State<WolfHeroBanner> createState() => _WolfHeroBannerState();
}

class _WolfHeroBannerState extends State<WolfHeroBanner> {
  late final PageController _page;
  Timer? _timer;
  var _index = 0;
  var _paused = false;

  List<MediaItem> get _slides {
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final item in widget.items) {
      if (item.id <= 0) continue;
      if (seen.add(item.dedupeKey)) out.add(item);
      if (out.length >= 8) break;
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant WolfHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _index = 0;
      if (_page.hasClients) {
        _page.jumpToPage(0);
      }
      _armTimer();
    }
  }

  void _armTimer() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _paused || !_page.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 780),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final screenH = MediaQuery.sizeOf(context).height;
    final h = (screenH * 0.56).clamp(380.0, 560.0);

    if (slides.isEmpty) {
      return SizedBox(
        height: h,
        child: const ColoredBox(color: WolfColors.voidBlack),
      );
    }

    return SizedBox(
      height: h,
      width: double.infinity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _paused = true),
        onExit: (_) {
          setState(() => _paused = false);
          _armTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _HeroSlide(
                item: slides[i],
                active: i == _index,
                onWatch: () => widget.onWatch(slides[i]),
                onBrowse: widget.onBrowse,
              ),
            ),
            if (slides.length > 1)
              Positioned(
                left: 20,
                right: 20,
                bottom: 14,
                child: Row(
                  children: [
                    for (var i = 0; i < slides.length; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          height: 2,
                          margin: EdgeInsets.only(
                            right: i == slides.length - 1 ? 0 : 4,
                          ),
                          color: i == _index
                              ? WolfColors.lime
                              : WolfColors.steel.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.item,
    required this.active,
    required this.onWatch,
    required this.onBrowse,
  });

  final MediaItem item;
  final bool active;
  final VoidCallback onWatch;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final backdrop = Env.backdropUrl(item.backdropPath ?? item.posterPath);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (backdrop.isNotEmpty)
          CachedNetworkImage(
            imageUrl: backdrop,
            fit: BoxFit.cover,
          )
              .animate(target: active ? 1 : 0)
              .scale(
                begin: const Offset(1.08, 1.08),
                end: const Offset(1.0, 1.0),
                duration: 5200.ms,
                curve: Curves.easeOut,
              )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [WolfColors.steel, WolfColors.voidBlack],
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: WolfColors.heroGradient),
        ),
        IgnorePointer(child: CustomPaint(painter: _GrainPainter())),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WolfBrandMark(compact: true),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HUNT. STREAM.\nDOMINATE.',
                          style: Theme.of(context).textTheme.displayMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                            .animate(key: ValueKey('tag-${item.id}'))
                            .fadeIn(duration: 420.ms)
                            .slideY(begin: 0.08),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: WolfColors.lime),
                        )
                            .animate(key: ValueKey('title-${item.id}'))
                            .fadeIn(delay: 80.ms, duration: 400.ms)
                            .slideX(begin: 0.04),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (item.year != null) '${item.year}',
                            if (item.voteAverage > 0)
                              '${item.voteAverage.toStringAsFixed(1)} ★',
                            item.kind == MediaKind.movie ? 'FILM' : 'SERIES',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ).animate().fadeIn(delay: 140.ms),
                        const SizedBox(height: 12),
                        const ScanLine(height: 2),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _FlatCta(
                              label: 'WATCH',
                              filled: true,
                              onTap: onWatch,
                            ),
                            const SizedBox(width: 10),
                            _FlatCta(
                              label: 'BROWSE',
                              filled: false,
                              onTap: onBrowse,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FlatCta extends StatelessWidget {
  const _FlatCta({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: filled ? WolfColors.lime : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: WolfColors.lime, width: 1.5),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: filled ? WolfColors.voidBlack : WolfColors.lime,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WolfColors.bone.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

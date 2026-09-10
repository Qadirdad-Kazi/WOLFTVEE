import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/models/media_item.dart';
import '../config/env.dart';
import '../motion/wolf_motion.dart';
import '../theme/wolf_colors.dart';
import 'tv_focusable.dart';

class WolfPoster extends StatefulWidget {
  const WolfPoster({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 118,
    this.index = 0,
    this.expand = false,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final int index;
  final bool expand;

  @override
  State<WolfPoster> createState() => _WolfPosterState();
}

class _WolfPosterState extends State<WolfPoster> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final url = Env.posterUrl(widget.item.posterPath);

    Widget image({required double? width, required double? height}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: WolfColors.slate,
          border: Border.all(
            color: _pressed ? WolfColors.lime : WolfColors.steel,
            width: 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: url.isEmpty
            ? const Center(
                child: Icon(Icons.movie_creation_outlined,
                    color: WolfColors.mist),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, _) =>
                    Container(color: WolfColors.slate),
                errorWidget: (context, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: WolfColors.mist,
                ),
              ),
      );
    }

    final meta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: WolfColors.bone,
                letterSpacing: 0.4,
                fontSize: 12,
                height: 1.2,
              ),
        ),
        Text(
          widget.item.kind == MediaKind.movie ? 'FILM' : 'SERIES',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 10),
        ),
      ],
    );

    final body = widget.expand
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: image(width: double.infinity, height: null)),
              meta,
            ],
          )
        : SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image(width: widget.width, height: widget.width * 1.5),
                meta,
              ],
            ),
          );

    return WolfTvFocusable(
      onActivate: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: WolfMotion.fast,
          curve: WolfMotion.sharpen,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_pressed ? -0.06 : 0)
            ..translateByDouble(0, _pressed ? -4.0 : 0.0, 0, 1),
          child: body,
        ),
      ),
    )
        .animate(delay: (60 * widget.index).ms)
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .slideY(begin: 0.12, curve: WolfMotion.hunt);
  }
}

class WolfRail extends StatelessWidget {
  const WolfRail({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
  });

  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onTapItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: WolfColors.lime),
              const SizedBox(width: 10),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return WolfPoster(
                item: item,
                index: i,
                onTap: () => onTapItem(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

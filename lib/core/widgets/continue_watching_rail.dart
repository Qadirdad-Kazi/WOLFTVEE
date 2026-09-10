import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/services/watch_progress_store.dart';
import '../theme/wolf_colors.dart';
import 'tv_focusable.dart';

class ContinueWatchingRail extends StatelessWidget {
  const ContinueWatchingRail({
    super.key,
    required this.entries,
    required this.onPlay,
    required this.onRemove,
  });

  final List<WatchProgressEntry> entries;
  final void Function(WatchProgressEntry entry) onPlay;
  final void Function(WatchProgressEntry entry) onRemove;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

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
                'CONTINUE WATCHING',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final entry = entries[i];
              return _ContinueCard(
                entry: entry,
                index: i,
                onPlay: () => onPlay(entry),
                onRemove: () => onRemove(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.entry,
    required this.index,
    required this.onPlay,
    required this.onRemove,
  });

  final WatchProgressEntry entry;
  final int index;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final poster = entry.posterUrl;
    return SizedBox(
      width: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: WolfTvFocusable(
              onActivate: onPlay,
              child: Material(
                color: WolfColors.slate,
                child: InkWell(
                  onTap: onPlay,
                  onLongPress: onRemove,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (poster.isNotEmpty)
                        CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: WolfColors.steel),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00070708),
                              Color(0xCC070708),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          color: WolfColors.lime,
                          child: const Icon(
                            Icons.play_arrow,
                            color: WolfColors.voidBlack,
                            size: 28,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: entry.progress.fraction,
                          minHeight: 3,
                          backgroundColor: WolfColors.steel,
                          color: WolfColors.lime,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: WolfTvFocusable(
                          onActivate: onRemove,
                          child: InkWell(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              color:
                                  WolfColors.voidBlack.withValues(alpha: 0.7),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: WolfColors.mist,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: WolfColors.bone,
                ),
          ),
          Text(
            entry.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    )
        .animate(delay: (40 * index).ms)
        .fadeIn(duration: 360.ms)
        .slideX(begin: 0.06);
  }
}

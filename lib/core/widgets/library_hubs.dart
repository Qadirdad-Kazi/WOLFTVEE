import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/models/media_item.dart';
import '../../data/services/favorites_store.dart';
import '../../data/services/watch_progress_store.dart';
import '../theme/wolf_colors.dart';
import 'tv_focusable.dart';

/// Two home hubs: Continue Watching + Favorites (no suggestions here —
/// those live on title detail pages).
class LibraryHubsRow extends StatelessWidget {
  const LibraryHubsRow({
    super.key,
    required this.continueEntries,
    required this.favorites,
    required this.onResume,
    required this.onRemoveContinue,
    required this.onOpenFavorite,
    required this.onRemoveFavorite,
  });

  final List<WatchProgressEntry> continueEntries;
  final List<FavoriteEntry> favorites;
  final void Function(WatchProgressEntry) onResume;
  final void Function(WatchProgressEntry) onRemoveContinue;
  final void Function(FavoriteEntry) onOpenFavorite;
  final void Function(FavoriteEntry) onRemoveFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: WolfColors.lime),
              const SizedBox(width: 10),
              Text(
                'YOUR LIBRARY',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HubCard(
                  title: 'CONTINUE',
                  subtitle: continueEntries.isEmpty
                      ? 'Nothing in progress'
                      : '${continueEntries.length} in progress',
                  icon: Icons.play_circle_outline,
                  previewUrl: continueEntries.isNotEmpty
                      ? continueEntries.first.posterUrl
                      : '',
                  accent: WolfColors.lime,
                  onTap: () => _openContinueSheet(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HubCard(
                  title: 'FAVORITES',
                  subtitle: favorites.isEmpty
                      ? 'Save titles you love'
                      : '${favorites.length} saved',
                  icon: Icons.favorite_border,
                  previewUrl:
                      favorites.isNotEmpty ? favorites.first.posterUrl : '',
                  accent: WolfColors.ember,
                  onTap: () => _openFavoritesSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.04);
  }

  void _openContinueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WolfColors.charcoal,
      isScrollControlled: true,
      builder: (ctx) => _LibrarySheet(
        title: 'CONTINUE WATCHING',
        emptyLabel: 'Start watching — progress shows up here.',
        child: continueEntries.isEmpty
            ? null
            : SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: continueEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final e = continueEntries[i];
                    return _PosterTile(
                      title: e.title,
                      subtitle: e.subtitle,
                      imageUrl: e.posterUrl,
                      progress: e.progress.fraction,
                      onTap: () {
                        Navigator.pop(ctx);
                        onResume(e);
                      },
                      onRemove: () => onRemoveContinue(e),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _openFavoritesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WolfColors.charcoal,
      isScrollControlled: true,
      builder: (ctx) => _LibrarySheet(
        title: 'FAVORITES',
        emptyLabel: 'Tap ♥ on a title to save it here.',
        child: favorites.isEmpty
            ? null
            : SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final f = favorites[i];
                    return _PosterTile(
                      title: f.title,
                      subtitle: f.kind == MediaKind.movie ? 'FILM' : 'SERIES',
                      imageUrl: f.posterUrl,
                      onTap: () {
                        Navigator.pop(ctx);
                        onOpenFavorite(f);
                      },
                      onRemove: () => onRemoveFavorite(f),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.previewUrl,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String previewUrl;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: WolfColors.slate,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 108,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewUrl.isNotEmpty)
                  Opacity(
                    opacity: 0.28,
                    child: CachedNetworkImage(
                      imageUrl: previewUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: WolfColors.steel),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        WolfColors.voidBlack.withValues(alpha: 0.35),
                        accent.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: accent, size: 22),
                      const Spacer(),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: WolfColors.bone,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibrarySheet extends StatelessWidget {
  const _LibrarySheet({
    required this.title,
    required this.emptyLabel,
    this.child,
  });

  final String title;
  final String emptyLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.48;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 3,
                  color: WolfColors.steel,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Expanded(
                child: child ??
                    Center(
                      child: Text(
                        emptyLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
    this.onRemove,
    this.progress,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: WolfTvFocusable(
              onActivate: onTap,
              child: Material(
                color: WolfColors.slate,
                child: InkWell(
                  onTap: onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        CachedNetworkImage(
                            imageUrl: imageUrl, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: WolfColors.steel),
                      if (progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            backgroundColor: WolfColors.steel,
                            color: WolfColors.lime,
                          ),
                        ),
                      if (onRemove != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: WolfTvFocusable(
                            onActivate: onRemove,
                            child: InkWell(
                              onTap: onRemove,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                color: WolfColors.voidBlack
                                    .withValues(alpha: 0.7),
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
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: WolfColors.bone,
                ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

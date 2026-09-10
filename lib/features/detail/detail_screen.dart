import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/config/env.dart';
import '../../core/playback/stream_nav.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/wolf_poster.dart';
import '../../data/models/media_item.dart';
import '../../data/services/elo_api_service.dart';
import '../../data/services/favorites_store.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.kind, required this.id});

  final MediaKind kind;
  final int id;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Future<MediaDetail>? _future;
  int _season = 1;
  List<TvEpisode> _episodes = const [];
  bool _loadingEps = false;
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _future = AppScope.repoOf(context).detail(widget.kind, widget.id);
  }

  Future<void> _loadEpisodes(int tvId, int season) async {
    setState(() {
      _season = season;
      _loadingEps = true;
    });
    try {
      final eps = await AppScope.repoOf(context).episodes(tvId, season);
      if (!mounted) return;
      setState(() {
        _episodes = eps;
        _loadingEps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaDetail>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: WolfColors.lime),
            ),
          );
        }
        final d = snap.data!;
        final backdrop = Env.backdropUrl(d.backdropPath);
        final poster = Env.posterUrl(d.posterPath);

        if (d.kind == MediaKind.tv &&
            d.seasons.isNotEmpty &&
            _episodes.isEmpty &&
            !_loadingEps) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadEpisodes(d.id, d.seasons.first.seasonNumber);
          });
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: WolfColors.voidBlack,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: backdrop,
                          fit: BoxFit.cover,
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(gradient: WolfColors.heroGradient),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (poster.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: poster,
                              width: 110,
                              height: 165,
                              fit: BoxFit.cover,
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style:
                                      Theme.of(context).textTheme.displaySmall,
                                ),
                                if (d.tagline.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    d.tagline,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _MetaChip(
                                      '${d.voteAverage.toStringAsFixed(1)} ★',
                                    ),
                                    if (d.releaseDate != null)
                                      _MetaChip(d.releaseDate!.split('-').first),
                                    if (d.runtime != null)
                                      _MetaChip('${d.runtime}m'),
                                    _MetaChip(
                                      d.kind == MediaKind.movie
                                          ? 'FILM'
                                          : 'SERIES',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn().slideY(begin: 0.08),
                      const SizedBox(height: 16),
                      const ScanLine(height: 2),
                      const SizedBox(height: 16),
                      Text(
                        d.overview,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: d.genres
                            .map(
                              (g) => Text(
                                g.toUpperCase(),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionBtn(
                              label: 'WATCH',
                              filled: true,
                              onTap: () {
                                final year = d.year ??
                                    int.tryParse(
                                      (d.releaseDate ?? '').split('-').first,
                                    );
                                if (d.kind == MediaKind.movie) {
                                  openStreamPlayer(
                                    context,
                                    title: d.title,
                                    kind: MediaKind.movie,
                                    mediaId: d.id,
                                    players: d.players,
                                    year: year,
                                  );
                                } else {
                                  final ep = _episodes.isNotEmpty
                                      ? _episodes.first
                                      : null;
                                  openStreamPlayer(
                                    context,
                                    title: ep != null
                                        ? '${d.title} · S$_season E${ep.episodeNumber}'
                                        : d.title,
                                    kind: MediaKind.tv,
                                    mediaId: d.id,
                                    players: ep?.players.isNotEmpty == true
                                        ? ep!.players
                                        : d.players,
                                    season: _season,
                                    episode: ep?.episodeNumber ?? 1,
                                    year: year,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          _FavoriteBtn(item: d),
                          if (d.trailerKey != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionBtn(
                                label: 'TRAILER',
                                filled: false,
                                onTap: () => context.push('/player', extra: {
                                  'title': d.title,
                                  'key': d.trailerKey,
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (d.kind == MediaKind.tv && d.seasons.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          'SEASONS',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.seasons.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final s = d.seasons[i];
                              final active = s.seasonNumber == _season;
                              return WolfTvFocusable(
                                onActivate: () =>
                                    _loadEpisodes(d.id, s.seasonNumber),
                                child: InkWell(
                                  onTap: () =>
                                      _loadEpisodes(d.id, s.seasonNumber),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? WolfColors.lime
                                          : WolfColors.slate,
                                      border: Border.all(
                                        color: active
                                            ? WolfColors.lime
                                            : WolfColors.steel,
                                      ),
                                    ),
                                    child: Text(
                                      'S${s.seasonNumber}',
                                      style: TextStyle(
                                        color: active
                                            ? WolfColors.voidBlack
                                            : WolfColors.bone,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_loadingEps)
                          const LinearProgressIndicator(
                            color: WolfColors.lime,
                            minHeight: 2,
                          )
                        else
                          ..._episodes.map(
                            (e) {
                              void play() => openStreamPlayer(
                                    context,
                                    title:
                                        '${d.title} · S${e.seasonNumber} E${e.episodeNumber}',
                                    kind: MediaKind.tv,
                                    mediaId: d.id,
                                    players: e.players.isNotEmpty
                                        ? e.players
                                        : d.players,
                                    season: e.seasonNumber,
                                    episode: e.episodeNumber,
                                    year: d.year ??
                                        int.tryParse(
                                          (d.releaseDate ?? '')
                                              .split('-')
                                              .first,
                                        ),
                                  );
                              return WolfTvFocusable(
                                onActivate: play,
                                child: Material(
                                  color: WolfColors.charcoal,
                                  child: InkWell(
                                    onTap: play,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: WolfColors.steel,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'E${e.episodeNumber.toString().padLeft(2, '0')}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                                if (e.overview.isNotEmpty)
                                                  Text(
                                                    e.overview,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.play_arrow,
                                            color: WolfColors.lime,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                      _MoreLikeThis(seed: d),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoreLikeThis extends StatelessWidget {
  const _MoreLikeThis({required this.seed});
  final MediaDetail seed;

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.catalogOf(context);
    final pool = <MediaItem>[
      ...catalog.movies,
      ...catalog.series,
      for (final r in catalog.catalog?.rails ?? const <CatalogRail>[]) ...r.items,
    ];
    final suggestions = FavoritesStore.suggestFrom(
      genreIds: seed.genreIds,
      genreNames: seed.genreNames.isNotEmpty ? seed.genreNames : seed.genres,
      pool: pool,
      excludeKeys: {seed.dedupeKey},
      limit: 14,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          'MORE LIKE THIS',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = suggestions[i];
              return WolfPoster(
                item: m,
                index: i % 8,
                onTap: () => context.push('/detail/${m.kind.name}/${m.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FavoriteBtn extends StatelessWidget {
  const _FavoriteBtn({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.favoritesOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = store.containsMedia(item);
        return WolfTvFocusable(
          onActivate: () => store.toggle(item),
          child: Material(
            color: WolfColors.steel,
            child: InkWell(
              onTap: () => store.toggle(item),
              child: Container(
                width: 52,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: on ? WolfColors.ember : WolfColors.mist,
                  ),
                ),
                child: Icon(
                  on ? Icons.favorite : Icons.favorite_border,
                  color: on ? WolfColors.ember : WolfColors.mist,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: WolfColors.steel),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.filled,
    this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: filled ? WolfColors.lime : WolfColors.steel,
        child: InkWell(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: filled ? WolfColors.lime : WolfColors.mist,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: filled ? WolfColors.voidBlack : WolfColors.mist,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

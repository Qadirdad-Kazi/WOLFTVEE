import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/playback/stream_nav.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/hunt_refresh.dart';
import '../../core/widgets/library_hubs.dart';
import '../../core/widgets/wolf_hero.dart';
import '../../core/widgets/wolf_poster.dart';
import '../../data/controllers/catalog_controller.dart';
import '../../data/models/media_item.dart';
import '../../data/services/favorites_store.dart';
import '../../data/services/watch_progress_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CatalogController _catalog;
  WatchProgressStore? _progress;
  FavoritesStore? _favorites;
  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _catalog = AppScope.catalogOf(context);
    _progress = AppScope.watchProgressOf(context);
    _favorites = AppScope.favoritesOf(context);
    _catalog.addListener(_onCatalog);
    _progress!.addListener(_onCatalog);
    _favorites!.addListener(_onCatalog);
    final settings = AppScope.settingsOf(context);
    _catalog.bootstrap(preferFresh: settings.autoRefreshOnOpen);
  }

  void _onCatalog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _catalog.removeListener(_onCatalog);
    _progress?.removeListener(_onCatalog);
    _favorites?.removeListener(_onCatalog);
    super.dispose();
  }

  void _open(MediaItem item) {
    context.push('/detail/${item.kind.name}/${item.id}');
  }

  void _resume(WatchProgressEntry entry) {
    final id = entry.tmdbId;
    if (id == null) return;
    openStreamPlayer(
      context,
      title: entry.isTv
          ? '${entry.title} · S${entry.resumeSeason} E${entry.resumeEpisode}'
          : entry.title,
      kind: entry.kind,
      mediaId: id,
      season: entry.resumeSeason,
      episode: entry.resumeEpisode,
    );
  }

  Future<void> _refresh() => _catalog.huntRefresh();

  @override
  Widget build(BuildContext context) {
    final sweeping = _catalog.phase == CatalogPhase.sweeping;
    final loading =
        _catalog.phase == CatalogPhase.loading && _catalog.catalog == null;
    final data = _catalog.catalog;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: WolfColors.lime),
      );
    }

    if (_catalog.phase == CatalogPhase.error && data == null) {
      return _ErrorPane(
        message: _catalog.error ?? 'Unknown error',
        onRetry: () => _catalog.bootstrap(preferFresh: true),
      );
    }

    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: WolfColors.lime),
      );
    }

    final gen = _catalog.lastUpdated?.millisecondsSinceEpoch ?? 0;
    final rails = data.rails;

    return Stack(
      children: [
        LiveCatalogSwitch(
          generation: gen,
          child: RefreshIndicator(
            color: WolfColors.lime,
            backgroundColor: WolfColors.slate,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      WolfHeroBanner(
                        items: [
                          if (data.hero != null) data.hero!,
                          ...data.trending,
                          ...data.nowPlaying,
                          ...data.popularMovies,
                        ],
                        onWatch: (item) {
                          openStreamPlayer(
                            context,
                            title: item.title,
                            kind: item.kind,
                            mediaId: item.id,
                            players: item.players,
                            year: item.year ??
                                int.tryParse(
                                  (item.releaseDate ?? '').split('-').first,
                                ),
                          );
                        },
                        onBrowse: () => context.go('/movies'),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        right: 16,
                        child: HuntRefreshButton(
                          compact: true,
                          busy: sweeping,
                          onPressed: _refresh,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_catalog.lastUpdated != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            'LIVE · ${DateFormat('HH:mm').format(_catalog.lastUpdated!)}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const Spacer(),
                          HuntRefreshButton(
                            busy: sweeping,
                            onPressed: _refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: LibraryHubsRow(
                    continueEntries: _progress?.continueWatching ?? const [],
                    favorites: _favorites?.items ?? const [],
                    onResume: _resume,
                    onRemoveContinue: (e) => _progress?.remove(e.id),
                    onOpenFavorite: (f) =>
                        context.push('/detail/${f.kind.name}/${f.id}'),
                    onRemoveFavorite: (f) =>
                        _favorites?.remove(f.kind, f.id),
                  ),
                ),
                if (rails.isNotEmpty)
                  for (final rail in rails)
                    SpacedRail(
                      title: rail.name,
                      items: rail.items,
                      onTapItem: _open,
                    )
                else ...[
                  SpacedRail(
                    title: 'Trending',
                    items: data.trending,
                    onTapItem: _open,
                  ),
                  SpacedRail(
                    title: 'Hollywood',
                    items: data.popularMovies,
                    onTapItem: _open,
                  ),
                  SpacedRail(
                    title: 'Bollywood',
                    items: data.topRatedMovies,
                    onTapItem: _open,
                  ),
                  SpacedRail(
                    title: 'Series',
                    items: data.popularTv,
                    onTapItem: _open,
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
        HuntSweepOverlay(active: sweeping),
      ],
    );
  }
}

class SpacedRail extends StatelessWidget {
  const SpacedRail({
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
    return SliverToBoxAdapter(
      child: WolfRail(title: title, items: items, onTapItem: onTapItem),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: WolfColors.ember, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child:
                const Text('RETRY', style: TextStyle(color: WolfColors.lime)),
          ),
        ],
      ),
    );
  }
}

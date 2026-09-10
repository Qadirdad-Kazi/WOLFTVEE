import '../models/media_item.dart';
import '../services/catalog_merge.dart';
import '../services/elo_api_service.dart';
import '../services/trakt_service.dart';
import '../services/tmdb_service.dart';

class CatalogBundle {
  const CatalogBundle({
    required this.hero,
    required this.trending,
    required this.popularMovies,
    required this.popularTv,
    required this.topRatedMovies,
    required this.topRatedTv,
    required this.nowPlaying,
    required this.airingToday,
    required this.movieGenres,
    required this.tvGenres,
    this.rails = const [],
  });

  final MediaItem? hero;
  final List<MediaItem> trending;
  final List<MediaItem> popularMovies;
  final List<MediaItem> popularTv;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> topRatedTv;
  final List<MediaItem> nowPlaying;
  final List<MediaItem> airingToday;
  final List<Genre> movieGenres;
  final List<Genre> tvGenres;
  final List<CatalogRail> rails;
}

class MediaRepository {
  MediaRepository({
    required EloApiService elo,
    TmdbService? tmdb,
    TraktService? trakt,
  })  : _elo = elo,
        _tmdb = tmdb,
        _trakt = trakt;

  final EloApiService _elo;
  final TmdbService? _tmdb;
  final TraktService? _trakt;

  final Map<int, MediaItem> _byId = {};

  void _index(Iterable<MediaItem> items) {
    for (final i in items) {
      // Prefer playable Elo when IDs collide across catalogs.
      final existing = _byId[i.id];
      if (existing == null ||
          (!existing.hasPlayableSource && i.hasPlayableSource)) {
        _byId[i.id] = i;
      }
    }
  }

  Future<CatalogBundle> loadHome() async {
    final eloFutures = Future.wait([
      _elo.homeRails(),
      _elo.hollywood(),
      _elo.bollywood(),
      _elo.serials(),
    ]);

    final discoveryFutures = Future.wait([
      _loadTraktOrTmdbMovies(),
      _loadTraktOrTmdbShows(),
    ]);

    final eloResults = await eloFutures;
    final discovery = await discoveryFutures;

    final rails = eloResults[0] as List<CatalogRail>;
    final hollywood = eloResults[1] as List<MediaItem>;
    final bollywood = eloResults[2] as List<MediaItem>;
    final serials = eloResults[3] as List<MediaItem>;
    final discMovies = discovery[0];
    final discShows = discovery[1];

    List<MediaItem> railNamed(String needle) {
      for (final r in rails) {
        if (r.name.toLowerCase().contains(needle)) return r.items;
      }
      return const [];
    }

    final eloMovies = CatalogMerge.merge(
      primary: [...hollywood, ...bollywood],
      secondary: const [],
    );
    final eloSeries = CatalogMerge.merge(
      primary: serials,
      secondary: const [],
    );

    // Newest Elo uploads rail (by created_at).
    final newestElo = [...eloMovies, ...eloSeries]
      ..sort((a, b) {
        final aAt = a.createdAt;
        final bAt = b.createdAt;
        if (aAt == null && bAt == null) return 0;
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        return bAt.compareTo(aAt);
      });

    final mergedMovies = CatalogMerge.merge(
      primary: eloMovies,
      secondary: discMovies,
    );
    final mergedSeries = CatalogMerge.merge(
      primary: eloSeries,
      secondary: discShows,
    );

    final claimed = <String>{};
    List<MediaItem> claim(List<MediaItem> source) {
      final out = <MediaItem>[];
      for (final item in source) {
        final fp = CatalogMerge.fingerprint(item);
        if (claimed.add(fp)) out.add(item);
      }
      return out;
    }

    // Newest Elo first so "Latest uploads" keeps true recency.
    final latestUploads = claim(newestElo.take(30).toList());
    final popular = claim(railNamed('popular'));
    final arriving = claim(
      railNamed('last arriv').isNotEmpty
          ? railNamed('last arriv')
          : newestElo.take(24).toList(),
    );
    final bwMovies = claim(
      railNamed('bollywood movies').isNotEmpty
          ? railNamed('bollywood movies')
          : bollywood,
    );
    final hwMovies = claim(
      railNamed('hollywood movies').isNotEmpty
          ? railNamed('hollywood movies')
          : hollywood,
    );
    final bwSeries = claim(railNamed('bollywood series'));
    final hwSeries = claim(
      railNamed('hollywood series').isNotEmpty
          ? railNamed('hollywood series')
          : serials,
    );
    final cartoons = claim(railNamed('cartoon'));
    final trendingDiscovery = claim([
      ...discMovies.take(20),
      ...discShows.take(20),
    ]);

    final gapFill = claim([
      for (final m in [...mergedMovies, ...mergedSeries])
        if (!m.hasPlayableSource) m,
    ]);

    final hero = latestUploads.isNotEmpty
        ? latestUploads.first
        : (popular.isNotEmpty
            ? popular.first
            : (hwMovies.isNotEmpty ? hwMovies.first : null));

    final mergedRails = <CatalogRail>[
      if (latestUploads.isNotEmpty)
        CatalogRail(name: 'Latest uploads', items: latestUploads),
      if (trendingDiscovery.isNotEmpty)
        CatalogRail(name: 'Trending now', items: trendingDiscovery),
      ...[
        for (final r in rails)
          CatalogRail(name: r.name, items: claim(r.items)),
      ],
      if (gapFill.isNotEmpty)
        CatalogRail(name: 'More to explore', items: gapFill.take(30).toList()),
    ];

    _index([
      for (final r in mergedRails) ...r.items,
      ...mergedMovies,
      ...mergedSeries,
      ...arriving,
      ...bwMovies,
      ...hwMovies,
      ...bwSeries,
      ...hwSeries,
      ...cartoons,
    ]);

    return CatalogBundle(
      hero: hero,
      trending: popular.skip(hero == null ? 0 : 1).toList(),
      popularMovies: hwMovies.isNotEmpty ? hwMovies : mergedMovies,
      popularTv: hwSeries.isNotEmpty ? hwSeries : mergedSeries,
      topRatedMovies: bwMovies,
      topRatedTv: bwSeries,
      nowPlaying: arriving,
      airingToday: cartoons,
      movieGenres: _genresFrom(mergedMovies),
      tvGenres: _genresFrom(mergedSeries),
      rails: mergedRails,
    );
  }

  Future<List<MediaItem>> _loadTraktOrTmdbMovies() async {
    try {
      if (_trakt != null && _trakt.enabled) {
        final list = await _trakt.trendingMovies();
        if (list.isNotEmpty) return list;
      }
      if (_tmdb != null && _tmdb.enabled) {
        return await _tmdb.trendingMovies();
      }
    } catch (e) {
      // Discovery is optional — Elo still serves home.
    }
    return const [];
  }

  Future<List<MediaItem>> _loadTraktOrTmdbShows() async {
    try {
      if (_trakt != null && _trakt.enabled) {
        final list = await _trakt.trendingShows();
        if (list.isNotEmpty) return list;
      }
      if (_tmdb != null && _tmdb.enabled) {
        return await _tmdb.trendingTv();
      }
    } catch (_) {}
    return const [];
  }

  List<Genre> _genresFrom(List<MediaItem> items) {
    final map = <String, Genre>{};
    for (final item in items) {
      for (var i = 0; i < item.genreNames.length; i++) {
        final name = item.genreNames[i];
        final id = i < item.genreIds.length
            ? item.genreIds[i]
            : name.hashCode.abs();
        map.putIfAbsent(name, () => Genre(id: id, name: name));
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<MediaItem>> search(String q) async {
    final elo = await _elo.search(q);
    List<MediaItem> tmdb = const [];
    if (_tmdb != null && _tmdb.enabled) {
      try {
        tmdb = await _tmdb.search(q);
      } catch (_) {}
    }
    final merged = CatalogMerge.merge(primary: elo, secondary: tmdb);
    _index(merged);
    return merged;
  }

  Future<MediaDetail> detail(MediaKind kind, int id) async {
    final cached = _byId[id];
    if (cached != null) {
      // Enrich TMDB-only / merged titles with seasons + trailer.
      final tmdbId = cached.tmdbId;
      if (_tmdb != null &&
          _tmdb.enabled &&
          tmdbId != null &&
          (!cached.hasPlayableSource || cached.kind == MediaKind.tv)) {
        final tmdbDetail = await _tmdb.detail(kind, tmdbId);
        if (tmdbDetail != null) {
          final merged = MediaDetail(
            id: cached.id,
            title: cached.title,
            kind: cached.kind,
            overview: cached.overview.trim().isNotEmpty
                ? cached.overview
                : tmdbDetail.overview,
            posterPath: cached.posterPath ?? tmdbDetail.posterPath,
            backdropPath: cached.backdropPath ?? tmdbDetail.backdropPath,
            voteAverage: cached.voteAverage > 0
                ? cached.voteAverage
                : tmdbDetail.voteAverage,
            releaseDate: cached.releaseDate ?? tmdbDetail.releaseDate,
            genreIds: cached.genreIds.isNotEmpty
                ? cached.genreIds
                : tmdbDetail.genreIds,
            genreNames: cached.genreNames.isNotEmpty
                ? cached.genreNames
                : tmdbDetail.genreNames,
            players: cached.players,
            year: cached.year ?? tmdbDetail.year,
            tmdbId: tmdbId,
            catalogOrigin: cached.catalogOrigin,
            createdAt: cached.createdAt,
            runtime: tmdbDetail.runtime,
            genres: tmdbDetail.genres.isNotEmpty
                ? tmdbDetail.genres
                : cached.genreNames,
            seasons: tmdbDetail.seasons,
            trailerKey: tmdbDetail.trailerKey,
            imdbId: tmdbDetail.imdbId,
            tagline: tmdbDetail.tagline,
          );
          _index([merged]);
          return merged;
        }
      }
      return MediaDetail.fromItem(cached);
    }

    final found = await _elo.detailById(id);
    if (found != null) {
      _index([found]);
      return found;
    }

    if (_tmdb != null && _tmdb.enabled) {
      final tmdbDetail = await _tmdb.detail(kind, id);
      if (tmdbDetail != null) {
        _index([tmdbDetail]);
        return tmdbDetail;
      }
    }
    throw StateError('Title $id not found');
  }

  Future<List<MediaItem>> byGenre(MediaKind kind, int genreId) async {
    final shelf = kind == MediaKind.movie
        ? await moviesShelf()
        : await seriesShelf();
    if (genreId < 0) return shelf;
    return shelf.where((m) => m.genreIds.contains(genreId)).toList();
  }

  Future<List<TvEpisode>> episodes(int tvId, int season) async {
    final item = _byId[tvId];
    final tmdbId = item?.tmdbId ??
        (item?.catalogOrigin == CatalogOrigin.tmdb ||
                item?.catalogOrigin == CatalogOrigin.trakt
            ? tvId
            : null);
    if (_tmdb != null && _tmdb.enabled && tmdbId != null) {
      return _tmdb.episodes(tmdbId, season);
    }
    return const [];
  }

  Future<List<MediaItem>> moviesShelf() async {
    final a = await _elo.hollywood();
    final b = await _elo.bollywood();
    final disc = await _loadTraktOrTmdbMovies();
    final out = CatalogMerge.merge(primary: [...a, ...b], secondary: disc);
    _index(out);
    return out;
  }

  Future<List<MediaItem>> seriesShelf() async {
    final a = await _elo.serials();
    final disc = await _loadTraktOrTmdbShows();
    final out = CatalogMerge.merge(primary: a, secondary: disc);
    _index(out);
    return out;
  }

  Future<List<Genre>> genres(MediaKind kind) async {
    final items =
        kind == MediaKind.movie ? await moviesShelf() : await seriesShelf();
    return _genresFrom(items);
  }

  Future<List<LiveChannel>> liveChannels({bool forceRefresh = false}) {
    return _elo.liveBroadcasts(forceRefresh: forceRefresh);
  }
}

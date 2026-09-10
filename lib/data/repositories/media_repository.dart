import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../services/catalog_merge.dart';
import '../services/elo_api_service.dart';
import '../services/iptv_org_service.dart';
import '../services/public_iptv_service.dart';
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
    this.movies = const [],
    this.series = const [],
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
  /// Full playable movie shelf (all Elo pages) — avoids a second catalog fetch.
  final List<MediaItem> movies;
  /// Full playable series shelf (all Elo pages) — avoids a second catalog fetch.
  final List<MediaItem> series;
  final List<CatalogRail> rails;
}

class MediaRepository {
  MediaRepository({
    required EloApiService elo,
    IptvOrgService? iptv,
    PublicIptvService? publicIptv,
    TmdbService? tmdb,
    TraktService? trakt,
  })  : _elo = elo,
        _iptv = iptv,
        _publicIptv = publicIptv,
        _tmdb = tmdb,
        _trakt = trakt;

  final EloApiService _elo;
  final IptvOrgService? _iptv;
  final PublicIptvService? _publicIptv;
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

  static List<MediaItem> _playableOnly(Iterable<MediaItem> items) =>
      [for (final m in items) if (m.hasPlayableSource) m];

  Future<CatalogBundle> loadHome() async {
    final eloResults = await Future.wait([
      _elo.homeRails(),
      _elo.hollywood(),
      _elo.bollywood(),
      _elo.serials(),
    ]);

    final rails = eloResults[0] as List<CatalogRail>;
    final hollywood = _playableOnly(eloResults[1] as List<MediaItem>);
    final bollywood = _playableOnly(eloResults[2] as List<MediaItem>);
    final serials = _playableOnly(eloResults[3] as List<MediaItem>);

    // Optional: enrich playable Elo posters/overview from Trakt/TMDB matches
    // without ever adding non-playable discovery titles to the UI.
    final discMovies = await _loadTraktOrTmdbMovies();
    final discShows = await _loadTraktOrTmdbShows();

    List<MediaItem> railNamed(String needle) {
      for (final r in rails) {
        if (r.name.toLowerCase().contains(needle)) {
          return _playableOnly(r.items);
        }
      }
      return const [];
    }

    final eloMovies = CatalogMerge.merge(
      primary: [...hollywood, ...bollywood],
      secondary: discMovies,
    );
    final eloSeries = CatalogMerge.merge(
      primary: serials,
      secondary: discShows,
    );
    // Keep only titles that still have a licensed stream after merge.
    final mergedMovies = _playableOnly(eloMovies);
    final mergedSeries = _playableOnly(eloSeries);

    final newestElo = [...mergedMovies, ...mergedSeries]
      ..sort((a, b) {
        final aAt = a.createdAt;
        final bAt = b.createdAt;
        if (aAt == null && bAt == null) return 0;
        if (aAt == null) return 1;
        if (bAt == null) return -1;
        return bAt.compareTo(aAt);
      });

    final claimed = <String>{};
    List<MediaItem> claim(List<MediaItem> source) {
      final out = <MediaItem>[];
      for (final item in source) {
        if (!item.hasPlayableSource) continue;
        final fp = CatalogMerge.fingerprint(item);
        if (claimed.add(fp)) out.add(item);
      }
      return out;
    }

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

    final hero = latestUploads.isNotEmpty
        ? latestUploads.first
        : (popular.isNotEmpty
            ? popular.first
            : (hwMovies.isNotEmpty ? hwMovies.first : null));

    final mergedRails = <CatalogRail>[
      if (latestUploads.isNotEmpty)
        CatalogRail(name: 'Latest uploads', items: latestUploads),
      ...[
        for (final r in rails)
          CatalogRail(name: r.name, items: claim(r.items)),
      ],
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
      movies: mergedMovies,
      series: mergedSeries,
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
    // Playable Elo only — do not surface discovery-only search hits.
    final playable = _playableOnly(elo);
    // Enrich posters from TMDB when titles match; still drop non-playable.
    List<MediaItem> tmdb = const [];
    if (_tmdb != null && _tmdb.enabled) {
      try {
        tmdb = await _tmdb.search(q);
      } catch (_) {}
    }
    final merged = _playableOnly(
      CatalogMerge.merge(primary: playable, secondary: tmdb),
    );
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

    // Do not open discovery-only titles (no licensed stream).
    throw StateError('Title $id not found in playable catalog');
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

  /// Full licensed movie shelf (all Elo pages). Playable only.
  Future<List<MediaItem>> moviesShelf() async {
    final a = await _elo.hollywood();
    final b = await _elo.bollywood();
    final disc = await _loadTraktOrTmdbMovies();
    final out = _playableOnly(
      CatalogMerge.merge(primary: [...a, ...b], secondary: disc),
    );
    _index(out);
    return out;
  }

  /// Full licensed series shelf (all Elo pages). Playable only.
  Future<List<MediaItem>> seriesShelf() async {
    final a = await _elo.serials();
    final disc = await _loadTraktOrTmdbShows();
    final out = _playableOnly(
      CatalogMerge.merge(primary: a, secondary: disc),
    );
    _index(out);
    return out;
  }

  Future<List<Genre>> genres(MediaKind kind) async {
    final items =
        kind == MediaKind.movie ? await moviesShelf() : await seriesShelf();
    return _genresFrom(items);
  }

  Future<List<LiveChannel>> liveChannels({bool forceRefresh = false}) async {
    final iptv = _iptv;
    final publicIptv = _publicIptv;
    final futures = <Future<List<LiveChannel>>>[
      if (iptv != null)
        iptv.liveChannels(forceRefresh: forceRefresh).catchError((Object e) {
          debugPrint('iptv-org live failed: $e');
          return <LiveChannel>[];
        }),
      if (publicIptv != null)
        publicIptv
            .liveChannels(forceRefresh: forceRefresh)
            .catchError((Object e) {
          debugPrint('publiciptv live failed: $e');
          return <LiveChannel>[];
        }),
      _elo.liveBroadcasts(forceRefresh: forceRefresh).catchError((Object e) {
        debugPrint('elo live failed: $e');
        return <LiveChannel>[];
      }),
    ];

    final buckets = await Future.wait(futures);
    final byId = <String, LiveChannel>{};
    // Prefer global IPTV catalog, then Public IPTV, then Elo.
    for (final list in buckets) {
      for (final ch in list) {
        final key = ch.id.isNotEmpty
            ? ch.id
            : '${ch.name.toLowerCase()}|${ch.streamUrl ?? ''}';
        byId.putIfAbsent(key, () => ch);
      }
    }

    final out = byId.values.toList()
      ..sort((a, b) {
        final as = a.category.toLowerCase() == 'sports' ? 0 : 1;
        final bs = b.category.toLowerCase() == 'sports' ? 0 : 1;
        if (as != bs) return as.compareTo(bs);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return out;
  }
}

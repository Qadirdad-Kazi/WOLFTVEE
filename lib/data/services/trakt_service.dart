import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../models/media_item.dart';
import 'cache_store.dart';
import 'tmdb_service.dart';

/// Trakt trending lists → TMDB IDs, then hydrate posters via [TmdbService].
///
/// Requires your own Trakt API Client ID in `.env` (never reuse keys from
/// another APK).
class TraktService {
  TraktService({
    required TmdbService tmdb,
    CacheStore? cache,
    http.Client? client,
  })  : _tmdb = tmdb,
        _cache = cache ?? CacheStore(),
        _client = client ?? http.Client();

  final TmdbService _tmdb;
  final CacheStore _cache;
  final http.Client _client;

  bool forceRefresh = false;

  bool get enabled => Env.hasTrakt && Env.hasTmdbKey;

  Future<List<MediaItem>> trendingMovies({int limit = 40}) async {
    final ids = await _trendingIds('movies', limit: limit);
    return _hydrate(ids, MediaKind.movie);
  }

  Future<List<MediaItem>> trendingShows({int limit = 40}) async {
    final ids = await _trendingIds('shows', limit: limit);
    return _hydrate(ids, MediaKind.tv);
  }

  Future<List<int>> _trendingIds(String type, {required int limit}) async {
    if (!Env.hasTrakt) return const [];
    final cacheKey = 'trakt:trend_$type';
    if (!forceRefresh) {
      final hit = await _cache.get(cacheKey);
      if (hit != null && hit['ids'] is List) {
        return [
          for (final e in hit['ids'] as List)
            if (e is int) e else int.tryParse('$e') ?? 0,
        ].where((id) => id > 0).toList();
      }
    }

    final uri = Uri.parse('${Env.traktBaseUrl}/$type/trending')
        .replace(queryParameters: {'limit': '$limit'});

    http.Response? res;
    for (var i = 0; i < Env.traktClientIds.length; i++) {
      final key = Env.traktClientIds[i];
      res = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': key,
          'User-Agent': 'WOLFTVEE/1.0',
        },
      );
      if (res.statusCode == 200) {
        if (i > 0) {
          debugPrint('TraktService: primary key failed — using fallback');
        }
        break;
      }
      debugPrint(
        'TraktService $type key#${i + 1} → ${res.statusCode}'
        '${i + 1 < Env.traktClientIds.length ? ' (trying fallback)' : ''}',
      );
    }

    if (res == null || res.statusCode != 200) {
      return const [];
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const [];
    final ids = <int>[];
    for (final row in decoded) {
      if (row is! Map) continue;
      final media = row[type == 'movies' ? 'movie' : 'show'];
      if (media is! Map) continue;
      final idsMap = media['ids'];
      if (idsMap is! Map) continue;
      final tmdb = idsMap['tmdb'];
      final id = tmdb is int ? tmdb : int.tryParse('$tmdb');
      if (id != null && id > 0) ids.add(id);
    }
    await _cache.set(cacheKey, {'ids': ids});
    debugPrint('TraktService $type: ${ids.length} tmdb ids');
    return ids;
  }

  Future<List<MediaItem>> _hydrate(List<int> tmdbIds, MediaKind kind) async {
    if (!_tmdb.enabled || tmdbIds.isEmpty) return const [];
    // Use trending lists already hydrated when possible; otherwise detail-lite
    // from popular/trending pages is enough — fetch week trending and filter.
    final pool = kind == MediaKind.movie
        ? await _tmdb.trendingMovies()
        : await _tmdb.trendingTv();
    final byId = {for (final m in pool) m.tmdbId ?? m.id: m};
    final out = <MediaItem>[];
    final missing = <int>[];
    for (final id in tmdbIds) {
      final hit = byId[id];
      if (hit != null) {
        out.add(hit.copyWith(catalogOrigin: CatalogOrigin.trakt));
      } else {
        missing.add(id);
      }
    }
    // Hydrate a few missing via detail (cap to keep home fast).
    for (final id in missing.take(12)) {
      final d = await _tmdb.detail(kind, id);
      if (d != null) {
        out.add(
          MediaItem(
            id: d.id,
            title: d.title,
            kind: d.kind,
            overview: d.overview,
            posterPath: d.posterPath,
            backdropPath: d.backdropPath,
            voteAverage: d.voteAverage,
            releaseDate: d.releaseDate,
            genreIds: d.genreIds,
            genreNames: d.genreNames,
            players: d.players,
            year: d.year,
            tmdbId: d.tmdbId ?? d.id,
            catalogOrigin: CatalogOrigin.trakt,
          ),
        );
      }
    }
    return out;
  }
}

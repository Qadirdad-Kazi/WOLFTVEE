import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../models/media_item.dart';
import 'cache_store.dart';

/// TMDB metadata client — secondary discovery + posters + detail enrichment.
class TmdbService {
  TmdbService({CacheStore? cache, http.Client? client})
      : _cache = cache ?? CacheStore(),
        _client = client ?? http.Client();

  final CacheStore _cache;
  final http.Client _client;

  bool forceRefresh = false;

  bool get enabled => Env.hasTmdbKey;

  Uri _uri(String path, [Map<String, String>? query]) {
    final q = <String, String>{
      'api_key': Env.tmdbApiKey,
      if (query != null) ...query,
    };
    return Uri.parse('${Env.tmdbBaseUrl}$path').replace(queryParameters: q);
  }

  Future<dynamic> _get(String path, String cacheKey,
      [Map<String, String>? query]) async {
    if (!enabled) return null;
    if (!forceRefresh) {
      final hit = await _cache.get(cacheKey);
      if (hit != null && hit['payload'] != null) return hit['payload'];
    }
    final res = await _client.get(_uri(path, query));
    if (res.statusCode != 200) {
      debugPrint('TmdbService $path → ${res.statusCode}');
      final stale = await _cache.get(cacheKey);
      if (stale != null) return stale['payload'];
      return null;
    }
    final decoded = jsonDecode(res.body);
    await _cache.set(cacheKey, {'payload': decoded});
    return decoded;
  }

  Future<List<MediaItem>> trendingMovies({int page = 1}) async {
    final raw = await _get(
      '/trending/movie/week',
      'tmdb:trend_movie_p$page',
      {'page': '$page'},
    );
    return _list(raw, MediaKind.movie);
  }

  Future<List<MediaItem>> trendingTv({int page = 1}) async {
    final raw = await _get(
      '/trending/tv/week',
      'tmdb:trend_tv_p$page',
      {'page': '$page'},
    );
    return _list(raw, MediaKind.tv);
  }

  Future<List<MediaItem>> popularMovies({int page = 1}) async {
    final raw = await _get(
      '/movie/popular',
      'tmdb:pop_movie_p$page',
      {'page': '$page'},
    );
    return _list(raw, MediaKind.movie);
  }

  Future<List<MediaItem>> popularTv({int page = 1}) async {
    final raw = await _get(
      '/tv/popular',
      'tmdb:pop_tv_p$page',
      {'page': '$page'},
    );
    return _list(raw, MediaKind.tv);
  }

  Future<List<MediaItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty || !enabled) return const [];
    final raw = await _get(
      '/search/multi',
      'tmdb:search:${q.toLowerCase()}',
      {'query': q},
    );
    if (raw is! Map || raw['results'] is! List) return const [];
    final out = <MediaItem>[];
    for (final e in raw['results'] as List) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final mt = (m['media_type'] ?? '').toString();
      if (mt == 'movie') {
        out.add(MediaItem.fromTmdb(m, MediaKind.movie));
      } else if (mt == 'tv') {
        out.add(MediaItem.fromTmdb(m, MediaKind.tv));
      }
    }
    return out;
  }

  Future<MediaDetail?> detail(MediaKind kind, int tmdbId) async {
    if (!enabled) return null;
    final type = kind == MediaKind.movie ? 'movie' : 'tv';
    final raw = await _get(
      '/$type/$tmdbId',
      'tmdb:detail_$type$tmdbId',
      {
        'append_to_response': kind == MediaKind.movie
            ? 'videos'
            : 'videos,seasons',
      },
    );
    if (raw is! Map) return null;
    return MediaDetail.fromTmdb(Map<String, dynamic>.from(raw), kind);
  }

  Future<List<TvEpisode>> episodes(int tvId, int season) async {
    if (!enabled) return const [];
    final raw = await _get(
      '/tv/$tvId/season/$season',
      'tmdb:eps_${tvId}_s$season',
    );
    if (raw is! Map || raw['episodes'] is! List) return const [];
    return [
      for (final e in raw['episodes'] as List)
        if (e is Map)
          TvEpisode.fromTmdb(Map<String, dynamic>.from(e), season),
    ];
  }

  List<MediaItem> _list(dynamic raw, MediaKind kind) {
    if (raw is! Map || raw['results'] is! List) return const [];
    return [
      for (final e in raw['results'] as List)
        if (e is Map) MediaItem.fromTmdb(Map<String, dynamic>.from(e), kind),
    ];
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../models/media_item.dart';
import 'cache_store.dart';

/// Licensed catalog + live API client (elochkaigolochla mapi).
class EloApiService {
  EloApiService({CacheStore? cache, http.Client? client})
      : _cache = cache ?? CacheStore(),
        _client = client ?? http.Client();

  final CacheStore _cache;
  final http.Client _client;

  bool forceRefresh = false;

  static const _ua = 'WOLFTVEE/1.0';

  Future<List<LiveChannel>> liveBroadcasts({bool forceRefresh = false}) async {
    final raw = await _getJson(
      'new-broadcasts',
      'elo:live_v1',
      force: forceRefresh,
    );
    final list = _results(raw);
    final out = <LiveChannel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      if (m['enabled'] == false) continue;
      final players = PlaySource.listFromJson(m['players'] ?? m['player']);
      final m3u8 = players.where((p) => p.isHls).toList();
      final sources = m3u8.isNotEmpty ? m3u8 : players;
      if (sources.isEmpty) continue;
      final best = sources.first;
      out.add(
        LiveChannel(
          id: '${m['id'] ?? out.length}',
          name: (m['title'] ?? 'Channel').toString(),
          category: 'Live',
          streamUrl: best.url,
          logoUrl: (m['poster_url'] ?? m['poster'])?.toString(),
          isLive: true,
          quality: best.quality,
          subtitle: best.label,
          sources: [
            for (final s in sources)
              LiveStreamSource(
                url: s.url,
                quality: s.quality,
                feed: s.label,
              ),
          ],
        ),
      );
    }
    debugPrint('EloApiService live: ${out.length} channels');
    return out;
  }

  Future<List<MediaItem>> hollywood({int page = 1}) =>
      _catalogList('catalog/hollywood', 'elo:hw_p$page', page: page);

  Future<List<MediaItem>> bollywood({int page = 1}) =>
      _catalogList('catalog/bollywood', 'elo:bw_p$page', page: page);

  Future<List<MediaItem>> serials({int page = 1}) =>
      _catalogList('catalog/serials', 'elo:ser_p$page', page: page);

  Future<List<CatalogRail>> homeRails({bool forceRefresh = false}) async {
    final raw = await _getJson(
      'catalog',
      'elo:home_v1',
      force: forceRefresh || this.forceRefresh,
    );
    final result = raw is Map ? raw['result'] : null;
    final full = result is Map ? result['full'] : null;
    if (full is! List) return const [];
    final rails = <CatalogRail>[];
    for (final r in full) {
      if (r is! Map) continue;
      final map = Map<String, dynamic>.from(r);
      final name = (map['name'] ?? 'Rail').toString();
      // Skip adult rail for default app surface.
      if (name.toLowerCase().contains('erotic')) continue;
      final movies = map['movies'];
      if (movies is! List) continue;
      final items = <MediaItem>[];
      for (final m in movies) {
        if (m is Map) {
          items.add(MediaItem.fromElo(Map<String, dynamic>.from(m)));
        }
      }
      if (items.isEmpty) continue;
      rails.add(CatalogRail(name: name, items: items));
    }
    debugPrint('EloApiService home rails: ${rails.length}');
    return rails;
  }

  Future<List<MediaItem>> _catalogList(
    String path,
    String cacheKey, {
    int page = 1,
  }) async {
    final raw = await _getJson(
      path,
      cacheKey,
      query: {'page': '$page'},
      force: forceRefresh,
    );
    final list = _results(raw);
    return [
      for (final item in list)
        if (item is Map) MediaItem.fromElo(Map<String, dynamic>.from(item)),
    ];
  }

  Future<MediaDetail?> detailById(int id) async {
    // API has no /movie/{id} — search known shelves.
    for (final loader in <Future<List<MediaItem>> Function()>[
      () => hollywood(),
      () => bollywood(),
      () => serials(),
      () async {
        final rails = await homeRails();
        return [for (final r in rails) ...r.items];
      },
    ]) {
      final items = await loader();
      for (final item in items) {
        if (item.id == id) return MediaDetail.fromItem(item);
      }
    }
    return null;
  }

  Future<List<MediaItem>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final pool = <MediaItem>[
      ...await hollywood(),
      ...await bollywood(),
      ...await serials(),
    ];
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final item in pool) {
      if (!seen.add(item.dedupeKey)) continue;
      if (item.title.toLowerCase().contains(q) ||
          item.overview.toLowerCase().contains(q)) {
        out.add(item);
      }
    }
    return out;
  }

  List<dynamic> _results(dynamic raw) {
    if (raw is Map && raw['results'] is List) return raw['results'] as List;
    if (raw is List) return raw;
    return const [];
  }

  Future<void> clearCache() => _cache.clear();

  Future<CacheStats> cacheStats() => _cache.stats();

  void updateCacheTtl(Duration ttl) {
    _cache.ttl = ttl;
  }

  Future<dynamic> _getJson(
    String path,
    String cacheKey, {
    Map<String, String>? query,
    bool force = false,
  }) async {
    final key = query == null || query.isEmpty
        ? cacheKey
        : '$cacheKey:${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (!force && !forceRefresh) {
      final hit = await _cache.get(key);
      if (hit != null && hit['payload'] != null) return hit['payload'];
    }

    final uri = Uri.parse('${Env.apiBaseUrl}/$path').replace(
      queryParameters: query,
    );
    final res = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': _ua,
      },
    );
    if (res.statusCode != 200) {
      final stale = await _cache.get(key);
      if (stale != null && stale['payload'] != null) return stale['payload'];
      throw StateError('API ${res.statusCode} for $uri');
    }
    final decoded = jsonDecode(res.body);
    await _cache.set(key, {'payload': decoded});
    return decoded;
  }
}

class CatalogRail {
  const CatalogRail({required this.name, required this.items});
  final String name;
  final List<MediaItem> items;
}

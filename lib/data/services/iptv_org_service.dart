import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../models/media_item.dart';
import 'cache_store.dart';

/// Open IPTV catalog client (iptv-org) — full channel + stream directory.
///
/// Builds playable [LiveChannel] entries (named channels with streams plus
/// titled orphan streams). Sports is prioritized in sort order.
class IptvOrgService {
  IptvOrgService({CacheStore? cache, http.Client? client})
      : _cache = cache ?? CacheStore(),
        _client = client ?? http.Client();

  final CacheStore _cache;
  final http.Client _client;

  static const _ua = 'WOLFTVEE/1.0';
  static const _cacheKey = 'iptv_org:live_v3';

  /// All playable live channels (NSFW excluded). Sports sorted first.
  Future<List<LiveChannel>> liveChannels({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final hit = await _cache.get(_cacheKey);
      final payload = hit?['channels'];
      if (payload is List && payload.isNotEmpty) {
        final cached = <LiveChannel>[
          for (final row in payload)
            if (row is Map)
              LiveChannel.fromJson(Map<String, dynamic>.from(row)),
        ];
        if (cached.isNotEmpty) {
          debugPrint('IptvOrgService cache hit: ${cached.length} channels');
          return cached;
        }
      }
    }

    final results = await Future.wait([
      _getJsonList('channels.json'),
      _getJsonList('streams.json'),
      _getJsonList('logos.json'),
      _getJsonList('countries.json'),
    ]);

    final channelsRaw = results[0];
    final streamsRaw = results[1];
    final logosRaw = results[2];
    final countriesRaw = results[3];

    final built = await compute(
      _buildChannelsIsolate,
      <String, dynamic>{
        'channels': channelsRaw,
        'streams': streamsRaw,
        'logos': logosRaw,
        'countries': countriesRaw,
      },
    );

    await _cache.set(_cacheKey, {
      'channels': [for (final c in built) c.toJson()],
      'savedNote': 'iptv-org playable catalog',
    });

    // Extend disk TTL conceptually by rewriting cache with longer window —
    // CacheStore uses its own TTL; bump via fresh write is enough per session.
    debugPrint(
      'IptvOrgService live: ${built.length} channels '
      '(sports=${built.where((c) => c.category == 'Sports').length})',
    );
    return built;
  }

  Future<List<dynamic>> _getJsonList(String file) async {
    final uri = Uri.parse('${Env.iptvOrgApiBase}/$file');
    final res = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': _ua,
      },
    );
    if (res.statusCode != 200) {
      throw StateError('IPTV API ${res.statusCode} for $uri');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    return const [];
  }
}

List<LiveChannel> _buildChannelsIsolate(Map<String, dynamic> payload) {
  final channelsRaw = (payload['channels'] as List?) ?? const [];
  final streamsRaw = (payload['streams'] as List?) ?? const [];
  final logosRaw = (payload['logos'] as List?) ?? const [];
  final countriesRaw = (payload['countries'] as List?) ?? const [];

  final countryNames = <String, String>{};
  for (final row in countriesRaw) {
    if (row is! Map) continue;
    final code = (row['code'] ?? '').toString().toUpperCase();
    final name = (row['name'] ?? '').toString();
    if (code.isNotEmpty && name.isNotEmpty) countryNames[code] = name;
  }

  final logoByChannel = <String, String>{};
  for (final row in logosRaw) {
    if (row is! Map) continue;
    final channel = row['channel']?.toString();
    final url = row['url']?.toString();
    if (channel == null ||
        channel.isEmpty ||
        url == null ||
        url.isEmpty ||
        logoByChannel.containsKey(channel)) {
      continue;
    }
    final inUse = row['in_use'];
    if (inUse == false) continue;
    logoByChannel[channel] = url;
  }

  final streamsByChannel = <String, List<_RawStream>>{};
  final orphanStreams = <_RawStream>[];
  for (final row in streamsRaw) {
    if (row is! Map) continue;
    final url = (row['url'] ?? '').toString().trim();
    if (url.isEmpty) continue;
    final stream = _RawStream(
      channelId: row['channel']?.toString(),
      url: url,
      quality: row['quality']?.toString(),
      title: row['title']?.toString(),
      userAgent: row['user_agent']?.toString(),
      referrer: (row['referrer'] ?? row['referer'])?.toString(),
      labels: [
        if (row['labels'] is List)
          for (final l in row['labels'] as List) l.toString(),
      ],
    );
    final cid = stream.channelId;
    if (cid == null || cid.isEmpty) {
      orphanStreams.add(stream);
    } else {
      (streamsByChannel[cid] ??= <_RawStream>[]).add(stream);
    }
  }

  for (final list in streamsByChannel.values) {
    list.sort(_compareStreams);
  }

  final out = <LiveChannel>[];
  for (final row in channelsRaw) {
    if (row is! Map) continue;
    if (row['is_nsfw'] == true) continue;
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) continue;
    final feeds = streamsByChannel[id];
    if (feeds == null || feeds.isEmpty) continue;

    final categories = <String>[
      if (row['categories'] is List)
        for (final c in row['categories'] as List) c.toString(),
    ];
    final category = _primaryCategory(categories);
    final country = (row['country'] ?? '').toString().toUpperCase();
    final best = feeds.first;
    final name = (row['name'] ?? id).toString();

    out.add(
      LiveChannel(
        id: id,
        name: name,
        category: category,
        streamUrl: best.url,
        logoUrl: logoByChannel[id],
        isLive: true,
        quality: best.quality,
        userAgent: best.userAgent,
        referrer: best.referrer,
        subtitle: [
          if (country.isNotEmpty) (countryNames[country] ?? country),
          if (feeds.length > 1) '${feeds.length} feeds',
        ].join(' · '),
        countryCode: country.isEmpty ? null : country,
        countryName: country.isEmpty ? null : (countryNames[country] ?? country),
        sources: [
          for (final s in feeds)
            LiveStreamSource(
              url: s.url,
              quality: s.quality,
              feed: s.title,
              userAgent: s.userAgent,
              referrer: s.referrer,
            ),
        ],
      ),
    );
  }

  // Titled streams without a channel id (often sports / specialty feeds).
  final seenOrphan = <String>{};
  for (final s in orphanStreams) {
    final title = (s.title ?? '').trim();
    if (title.isEmpty) continue;
    final key = '${title.toLowerCase()}|${s.url}';
    if (!seenOrphan.add(key)) continue;
    final id = 'orphan:${title.hashCode.abs()}:${s.url.hashCode.abs()}';
    final category = _guessCategoryFromTitle(title);
    out.add(
      LiveChannel(
        id: id,
        name: title,
        category: category,
        streamUrl: s.url,
        isLive: !s.labels.any((l) => l.toLowerCase().contains('not 24/7')),
        quality: s.quality,
        userAgent: s.userAgent,
        referrer: s.referrer,
        subtitle: s.quality,
        sources: [
          LiveStreamSource(
            url: s.url,
            quality: s.quality,
            feed: title,
            userAgent: s.userAgent,
            referrer: s.referrer,
          ),
        ],
      ),
    );
  }

  out.sort((a, b) {
    final as = a.category.toLowerCase() == 'sports' ? 0 : 1;
    final bs = b.category.toLowerCase() == 'sports' ? 0 : 1;
    if (as != bs) return as.compareTo(bs);
    final cat = a.category.toLowerCase().compareTo(b.category.toLowerCase());
    if (cat != 0) return cat;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return out;
}

class _RawStream {
  const _RawStream({
    required this.url,
    this.channelId,
    this.quality,
    this.title,
    this.userAgent,
    this.referrer,
    this.labels = const [],
  });

  final String? channelId;
  final String url;
  final String? quality;
  final String? title;
  final String? userAgent;
  final String? referrer;
  final List<String> labels;
}

int _compareStreams(_RawStream a, _RawStream b) {
  final aq = _qualityRank(a.quality);
  final bq = _qualityRank(b.quality);
  if (aq != bq) return bq.compareTo(aq);
  final aHttps = a.url.startsWith('https://') ? 1 : 0;
  final bHttps = b.url.startsWith('https://') ? 1 : 0;
  if (aHttps != bHttps) return bHttps.compareTo(aHttps);
  final ah = a.url.contains('.m3u8') ? 1 : 0;
  final bh = b.url.contains('.m3u8') ? 1 : 0;
  return bh.compareTo(ah);
}

int _qualityRank(String? q) {
  if (q == null || q.isEmpty) return 0;
  final lower = q.toLowerCase();
  final match = RegExp(r'(\d{3,4})').firstMatch(lower);
  if (match != null) return int.tryParse(match.group(1)!) ?? 0;
  if (lower.contains('uhd') || lower.contains('4k')) return 2160;
  if (lower.contains('fhd')) return 1080;
  if (lower.contains('hd')) return 720;
  if (lower.contains('sd')) return 480;
  return 0;
}

String _primaryCategory(List<String> categories) {
  if (categories.isEmpty) return 'Other';
  const priority = [
    'sports',
    'news',
    'movies',
    'series',
    'entertainment',
    'kids',
    'music',
    'documentary',
    'general',
  ];
  for (final p in priority) {
    for (final c in categories) {
      if (c.toLowerCase() == p) return _titleCase(c);
    }
  }
  return _titleCase(categories.first);
}

String _guessCategoryFromTitle(String title) {
  final t = title.toLowerCase();
  const sportsHints = [
    'sport',
    'espn',
    'nba',
    'nfl',
    'mlb',
    'nhl',
    'fifa',
    'uefa',
    'soccer',
    'football',
    'tennis',
    'golf',
    'racing',
    'f1',
    'motogp',
    'ufc',
    'boxing',
    'cricket',
    'premier',
    'sky sport',
    'bein',
    'dazn',
  ];
  for (final h in sportsHints) {
    if (t.contains(h.toLowerCase())) return 'Sports';
  }
  if (t.contains('news') || t.contains('cnn') || t.contains('bbc')) {
    return 'News';
  }
  if (t.contains('kids') || t.contains('cartoon') || t.contains('disney')) {
    return 'Kids';
  }
  if (t.contains('music') || t.contains('mtv')) return 'Music';
  if (t.contains('movie') || t.contains('cinema')) return 'Movies';
  return 'Other';
}

String _titleCase(String raw) {
  if (raw.isEmpty) return 'Other';
  return raw
      .split(RegExp(r'[\s_-]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
      .join(' ');
}

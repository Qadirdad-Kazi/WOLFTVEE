import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env.dart';
import '../models/media_item.dart';
import 'cache_store.dart';

/// Optional Public IPTV client (your publiciptv.com host).
///
/// Public metadata (categories / countries) is always available.
/// Full channel list requires [Env.publicIptvToken] until `/api/channels`
/// is opened without auth.
class PublicIptvService {
  PublicIptvService({CacheStore? cache, http.Client? client})
      : _cache = cache ?? CacheStore(),
        _client = client ?? http.Client();

  final CacheStore _cache;
  final http.Client _client;

  static const _ua = 'WOLFTVEE/1.0';
  static const _cacheKey = 'public_iptv:channels_v1';

  Future<List<LiveChannel>> liveChannels({bool forceRefresh = false}) async {
    if (!Env.hasPublicIptvToken) return const [];

    if (!forceRefresh) {
      final hit = await _cache.get(_cacheKey);
      final payload = hit?['channels'];
      if (payload is List && payload.isNotEmpty) {
        return [
          for (final row in payload)
            if (row is Map)
              LiveChannel.fromJson(Map<String, dynamic>.from(row)),
        ];
      }
    }

    final uri = Uri.parse('${Env.publicIptvBaseUrl}/api/channels');
    final headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': _ua,
      'Authorization': 'Bearer ${Env.publicIptvToken}',
    };
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      debugPrint('PublicIptvService channels ${res.statusCode}');
      return const [];
    }

    final decoded = jsonDecode(res.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map && decoded['channels'] is List)
            ? decoded['channels'] as List
            : const [];

    final out = <LiveChannel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final mapped = _mapChannel(m);
      if (mapped != null) out.add(mapped);
    }

    if (out.isNotEmpty) {
      await _cache.set(_cacheKey, {
        'channels': [for (final c in out) c.toJson()],
      });
    }
    debugPrint('PublicIptvService live: ${out.length} channels');
    return out;
  }

  LiveChannel? _mapChannel(Map<String, dynamic> m) {
    final id = (m['id'] ?? m['channel_id'] ?? m['slug'] ?? '').toString();
    final name = (m['name'] ?? m['title'] ?? '').toString();
    if (name.isEmpty) return null;

    final categories = <String>[];
    final cats = m['categories'] ?? m['category'];
    if (cats is List) {
      for (final c in cats) {
        categories.add(c.toString());
      }
    } else if (cats != null) {
      categories.add(cats.toString());
    }
    final category = categories.isEmpty
        ? 'Other'
        : _titleCase(categories.first);

    final sources = <LiveStreamSource>[];
    final streams = m['streams'] ?? m['urls'] ?? m['players'];
    if (streams is List) {
      for (final s in streams) {
        if (s is String && s.isNotEmpty) {
          sources.add(LiveStreamSource(url: s));
        } else if (s is Map) {
          final url = (s['url'] ?? s['stream'] ?? '').toString();
          if (url.isEmpty) continue;
          sources.add(
            LiveStreamSource(
              url: url,
              quality: s['quality']?.toString(),
              feed: s['title']?.toString(),
              userAgent: s['user_agent']?.toString(),
              referrer: (s['referrer'] ?? s['referer'])?.toString(),
            ),
          );
        }
      }
    }
    final single = (m['url'] ?? m['stream_url'] ?? m['stream']).toString();
    if (sources.isEmpty && single.isNotEmpty) {
      sources.add(LiveStreamSource(url: single));
    }
    if (sources.isEmpty) return null;

    final country = (m['country'] ?? m['country_code'] ?? '').toString();
    return LiveChannel(
      id: id.isEmpty ? 'pub:${name.hashCode.abs()}' : id,
      name: name,
      category: category,
      streamUrl: sources.first.url,
      logoUrl: (m['logo'] ?? m['logo_url'] ?? m['tvg_logo'])?.toString(),
      isLive: m['is_live'] != false,
      quality: sources.first.quality,
      subtitle: (m['country_name'] ?? country).toString().isEmpty
          ? null
          : (m['country_name'] ?? country).toString(),
      countryCode: country.isEmpty ? null : country.toUpperCase(),
      countryName: m['country_name']?.toString(),
      sources: sources,
    );
  }

  String _titleCase(String raw) {
    if (raw.isEmpty) return 'Other';
    return raw
        .split(RegExp(r'[\s_-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// Remembers dead / alive IPTV stream URLs so Live TV can hide broken feeds.
///
/// Dead entries expire after [ttl]. Alive probes expire sooner so we re-check.
class DeadStreamStore extends ChangeNotifier {
  DeadStreamStore({
    this.ttl = const Duration(days: 7),
    this.aliveTtl = const Duration(hours: 24),
  });

  final Duration ttl;
  final Duration aliveTtl;

  static const _prefsKey = 'wolftvee_dead_streams_v2';

  final Map<String, int> _deadUrls = {};
  final Map<String, int> _deadChannels = {};
  final Map<String, int> _aliveUrls = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get deadUrlCount => _deadUrls.length;
  int get deadChannelCount => _deadChannels.length;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? prefs.getString('wolftvee_dead_streams_v1');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _readMap(decoded['urls'], _deadUrls);
          _readMap(decoded['channels'], _deadChannels);
          _readMap(decoded['alive'], _aliveUrls);
        }
      }
      _pruneExpired();
    } catch (e) {
      debugPrint('DeadStreamStore load failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  void _readMap(Object? raw, Map<String, int> into) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final ms = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
      if (ms > 0) into['$k'] = ms;
    });
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'urls': _deadUrls,
          'channels': _deadChannels,
          'alive': _aliveUrls,
        }),
      );
    } catch (e) {
      debugPrint('DeadStreamStore persist failed: $e');
    }
  }

  void _pruneExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadCut = now - ttl.inMilliseconds;
    final aliveCut = now - aliveTtl.inMilliseconds;
    _deadUrls.removeWhere((_, ms) => ms < deadCut);
    _deadChannels.removeWhere((_, ms) => ms < deadCut);
    _aliveUrls.removeWhere((_, ms) => ms < aliveCut);
  }

  bool isUrlDead(String? url) {
    if (url == null || url.isEmpty) return true;
    final ms = _deadUrls[url];
    if (ms == null) return false;
    if (ms < DateTime.now().subtract(ttl).millisecondsSinceEpoch) {
      _deadUrls.remove(url);
      return false;
    }
    return true;
  }

  bool isUrlAlive(String? url) {
    if (url == null || url.isEmpty) return false;
    final ms = _aliveUrls[url];
    if (ms == null) return false;
    if (ms < DateTime.now().subtract(aliveTtl).millisecondsSinceEpoch) {
      _aliveUrls.remove(url);
      return false;
    }
    return true;
  }

  /// True when we have no fresh probe result for this URL.
  bool needsProbe(String? url) {
    if (url == null || url.isEmpty) return false;
    if (isUrlDead(url)) return false;
    if (isUrlAlive(url)) return false;
    return true;
  }

  bool isChannelDead(String? id) {
    if (id == null || id.isEmpty) return false;
    final ms = _deadChannels[id];
    if (ms == null) return false;
    if (ms < DateTime.now().subtract(ttl).millisecondsSinceEpoch) {
      _deadChannels.remove(id);
      return false;
    }
    return true;
  }

  Future<void> markUrlDead(String url) async {
    if (url.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _deadUrls[url] = now;
    _aliveUrls.remove(url);
    await _persist();
    notifyListeners();
  }

  Future<void> markChannelDead(String id) async {
    if (id.isEmpty) return;
    _deadChannels[id] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
    notifyListeners();
  }

  Future<void> applyProbeResults({
    List<String> deadUrls = const [],
    List<String> deadChannels = const [],
    List<String> aliveUrls = const [],
  }) async {
    if (deadUrls.isEmpty && deadChannels.isEmpty && aliveUrls.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final u in deadUrls) {
      if (u.isEmpty) continue;
      _deadUrls[u] = now;
      _aliveUrls.remove(u);
    }
    for (final id in deadChannels) {
      if (id.isEmpty) continue;
      _deadChannels[id] = now;
    }
    for (final u in aliveUrls) {
      if (u.isEmpty) continue;
      _aliveUrls[u] = now;
      _deadUrls.remove(u);
    }
    await _persist();
    notifyListeners();
  }

  /// Drop dead sources; returns null if nothing playable remains.
  LiveChannel? livingChannel(LiveChannel channel) {
    if (isChannelDead(channel.id)) return null;
    final livingSources = [
      for (final s in channel.selectableSources)
        if (!isUrlDead(s.url)) s,
    ];
    if (livingSources.isEmpty) return null;
    // Prefer a recently verified-alive source when available.
    livingSources.sort((a, b) {
      final aa = isUrlAlive(a.url) ? 0 : 1;
      final bb = isUrlAlive(b.url) ? 0 : 1;
      return aa.compareTo(bb);
    });
    final best = livingSources.first;
    return LiveChannel(
      id: channel.id,
      name: channel.name,
      category: channel.category,
      streamUrl: best.url,
      logoUrl: channel.logoUrl,
      isLive: channel.isLive,
      quality: best.quality ?? channel.quality,
      userAgent: best.userAgent ?? channel.userAgent,
      referrer: best.referrer ?? channel.referrer,
      subtitle: channel.subtitle,
      countryCode: channel.countryCode,
      countryName: channel.countryName,
      sources: livingSources,
    );
  }

  List<LiveChannel> filterChannels(Iterable<LiveChannel> channels) {
    final out = <LiveChannel>[];
    for (final ch in channels) {
      final living = livingChannel(ch);
      if (living != null) out.add(living);
    }
    return out;
  }

  Future<void> clear() async {
    _deadUrls.clear();
    _deadChannels.clear();
    _aliveUrls.clear();
    await _persist();
    notifyListeners();
  }
}

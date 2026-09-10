import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env.dart';
import '../models/media_item.dart';

class WatchProgressPoint {
  const WatchProgressPoint({
    required this.watched,
    required this.duration,
  });

  final double watched;
  final double duration;

  double get fraction {
    if (duration <= 0) return 0;
    return (watched / duration).clamp(0.0, 1.0);
  }

  bool get isNearlyFinished => fraction >= 0.92;

  factory WatchProgressPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WatchProgressPoint(watched: 0, duration: 0);
    }
    return WatchProgressPoint(
      watched: (json['watched'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'watched': watched,
        'duration': duration,
      };
}

class EpisodeProgress {
  const EpisodeProgress({
    required this.season,
    required this.episode,
    required this.progress,
    required this.lastUpdated,
  });

  final int season;
  final int episode;
  final WatchProgressPoint progress;
  final int lastUpdated;

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      season: int.tryParse('${json['season']}') ?? 1,
      episode: int.tryParse('${json['episode']}') ?? 1,
      progress: WatchProgressPoint.fromJson(
        json['progress'] as Map<String, dynamic>?,
      ),
      lastUpdated: (json['last_updated'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'season': '$season',
        'episode': '$episode',
        'progress': progress.toJson(),
        'last_updated': lastUpdated,
      };
}

/// One title tracked for Continue Watching (WOLFTVEE progress shape).
class WatchProgressEntry {
  const WatchProgressEntry({
    required this.id,
    required this.type,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.progress,
    required this.lastUpdated,
    this.numberOfEpisodes,
    this.numberOfSeasons,
    this.lastSeasonWatched,
    this.lastEpisodeWatched,
    this.showProgress = const {},
  });

  final String id;
  final String type; // movie | tv
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final WatchProgressPoint progress;
  final int lastUpdated;
  final int? numberOfEpisodes;
  final int? numberOfSeasons;
  final int? lastSeasonWatched;
  final int? lastEpisodeWatched;
  final Map<String, EpisodeProgress> showProgress;

  bool get isTv => type == 'tv';
  MediaKind get kind => isTv ? MediaKind.tv : MediaKind.movie;
  int? get tmdbId => int.tryParse(id);

  int get resumeSeason => lastSeasonWatched ?? 1;
  int get resumeEpisode => lastEpisodeWatched ?? 1;

  String get subtitle {
    if (isTv) {
      return 'S$resumeSeason E$resumeEpisode · ${(progress.fraction * 100).round()}%';
    }
    return '${(progress.fraction * 100).round()}% watched';
  }

  String get posterUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return Env.posterUrl(path);
  }

  String get backdropUrl {
    final path = backdropPath;
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return Env.backdropUrl(path);
  }

  factory WatchProgressEntry.fromJson(String key, Map<String, dynamic> json) {
    final showRaw = json['show_progress'] as Map<String, dynamic>? ?? {};
    final show = <String, EpisodeProgress>{};
    for (final e in showRaw.entries) {
      if (e.value is Map<String, dynamic>) {
        show[e.key] = EpisodeProgress.fromJson(e.value as Map<String, dynamic>);
      }
    }

    return WatchProgressEntry(
      id: (json['id'] ?? key).toString(),
      type: (json['type'] ?? 'movie').toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      progress: WatchProgressPoint.fromJson(
        json['progress'] as Map<String, dynamic>?,
      ),
      lastUpdated: (json['last_updated'] as num?)?.toInt() ?? 0,
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      lastSeasonWatched: int.tryParse('${json['last_season_watched'] ?? ''}'),
      lastEpisodeWatched: int.tryParse('${json['last_episode_watched'] ?? ''}'),
      showProgress: show,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'progress': progress.toJson(),
        'last_updated': lastUpdated,
        if (numberOfEpisodes != null) 'number_of_episodes': numberOfEpisodes,
        if (numberOfSeasons != null) 'number_of_seasons': numberOfSeasons,
        if (lastSeasonWatched != null)
          'last_season_watched': '$lastSeasonWatched',
        if (lastEpisodeWatched != null)
          'last_episode_watched': '$lastEpisodeWatched',
        if (showProgress.isNotEmpty)
          'show_progress': {
            for (final e in showProgress.entries) e.key: e.value.toJson(),
          },
      };
}

/// Persists WOLFTVEE watch progress for Continue Watching.
class WatchProgressStore extends ChangeNotifier {
  WatchProgressStore();

  static const _kKey = 'wolftvee-Progress';

  final Map<String, WatchProgressEntry> _entries = {};

  List<WatchProgressEntry> get continueWatching {
    final list = _entries.values
        .where((e) => !e.progress.isNearlyFinished && e.progress.watched > 5)
        .toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return list;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_kKey);
    // Migrate legacy progress key if present.
    raw ??= prefs.getString('vidukinet-Progress');
    _entries.clear();
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final e in decoded.entries) {
          if (e.value is Map<String, dynamic>) {
            _entries[e.key] = WatchProgressEntry.fromJson(
              e.key,
              e.value as Map<String, dynamic>,
            );
          }
        }
      }
      await _persist();
      await prefs.remove('vidukinet-Progress');
    } catch (err) {
      debugPrint('WatchProgressStore load failed: $err');
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      for (final e in _entries.entries) e.key: e.value.toJson(),
    };
    await prefs.setString(_kKey, jsonEncode(map));
  }

  /// Handles WOLFTVEE `MEDIA_DATA` payload (full map or single entry).
  Future<void> ingestMessageData(dynamic data) async {
    if (data == null) return;

    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return;
      }
    }

    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);

    final isSingle = map.containsKey('type') &&
        (map.containsKey('id') || map.containsKey('progress'));

    if (isSingle) {
      final id = (map['id'] ?? '').toString();
      if (id.isEmpty) return;
      _entries[id] = WatchProgressEntry.fromJson(id, map);
    } else {
      for (final e in map.entries) {
        if (e.value is Map) {
          final entry = WatchProgressEntry.fromJson(
            e.key,
            Map<String, dynamic>.from(e.value as Map),
          );
          _entries[entry.id] = entry;
        }
      }
    }

    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  /// Upsert progress from native HLS playback.
  Future<void> upsertPlayback({
    required String id,
    required String type,
    required String title,
    String? posterPath,
    String? backdropPath,
    required double watchedSec,
    required double durationSec,
    int season = 1,
    int episode = 1,
  }) async {
    if (id.isEmpty || watchedSec < 3) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _entries[id];
    final point = WatchProgressPoint(
      watched: watchedSec,
      duration: durationSec > 0 ? durationSec : (existing?.progress.duration ?? 0),
    );

    if (type == 'tv') {
      final show = Map<String, EpisodeProgress>.from(
        existing?.showProgress ?? {},
      );
      final epKey = 's${season}e$episode';
      show[epKey] = EpisodeProgress(
        season: season,
        episode: episode,
        progress: point,
        lastUpdated: now,
      );
      _entries[id] = WatchProgressEntry(
        id: id,
        type: 'tv',
        title: title,
        posterPath: posterPath ?? existing?.posterPath,
        backdropPath: backdropPath ?? existing?.backdropPath,
        progress: point,
        lastUpdated: now,
        lastSeasonWatched: season,
        lastEpisodeWatched: episode,
        showProgress: show,
        numberOfEpisodes: existing?.numberOfEpisodes,
        numberOfSeasons: existing?.numberOfSeasons,
      );
    } else {
      _entries[id] = WatchProgressEntry(
        id: id,
        type: 'movie',
        title: title,
        posterPath: posterPath ?? existing?.posterPath,
        backdropPath: backdropPath ?? existing?.backdropPath,
        progress: point,
        lastUpdated: now,
      );
    }
    await _persist();
    notifyListeners();
  }
}

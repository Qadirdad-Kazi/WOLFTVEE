import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env.dart';
import '../models/media_item.dart';

class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.genreIds = const [],
    this.genreNames = const [],
    required this.addedAt,
  });

  final int id;
  final MediaKind kind;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final List<int> genreIds;
  final List<String> genreNames;
  final int addedAt;

  String get key => '${kind.name}:$id';

  String get posterUrl {
    final path = posterPath;
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return Env.posterUrl(path);
  }

  factory FavoriteEntry.fromMedia(MediaItem item) {
    return FavoriteEntry(
      id: item.id,
      kind: item.kind,
      title: item.title,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      genreIds: item.genreIds,
      genreNames: item.genreNames,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory FavoriteEntry.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] ?? 'movie').toString();
    return FavoriteEntry(
      id: int.tryParse('${json['id']}') ?? 0,
      kind: kindRaw == 'tv' ? MediaKind.tv : MediaKind.movie,
      title: (json['title'] ?? 'Untitled').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      genreIds: [
        for (final g in (json['genre_ids'] as List? ?? const []))
          if (g is int) g else int.tryParse('$g') ?? 0,
      ].where((e) => e > 0).toList(),
      genreNames: [
        for (final g in (json['genre_names'] as List? ?? const []))
          g.toString(),
      ],
      addedAt: (json['added_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'genre_ids': genreIds,
        'genre_names': genreNames,
        'added_at': addedAt,
      };
}

class FavoritesStore extends ChangeNotifier {
  FavoritesStore();

  static const _kKey = 'wolftvee_favorites_v1';

  final Map<String, FavoriteEntry> _entries = {};

  List<FavoriteEntry> get items {
    final list = _entries.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  int get count => _entries.length;

  bool contains(MediaKind kind, int id) =>
      _entries.containsKey('${kind.name}:$id');

  bool containsMedia(MediaItem item) => contains(item.kind, item.id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    _entries.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            if (e.value is Map) {
              final entry = FavoriteEntry.fromJson(
                Map<String, dynamic>.from(e.value as Map),
              );
              if (entry.id > 0) _entries[entry.key] = entry;
            }
          }
        }
      } catch (err) {
        debugPrint('FavoritesStore load failed: $err');
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode({for (final e in _entries.entries) e.key: e.value.toJson()}),
    );
  }

  Future<void> toggle(MediaItem item) async {
    final key = '${item.kind.name}:${item.id}';
    if (_entries.containsKey(key)) {
      _entries.remove(key);
    } else {
      _entries[key] = FavoriteEntry.fromMedia(item);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> add(MediaItem item) async {
    _entries['${item.kind.name}:${item.id}'] = FavoriteEntry.fromMedia(item);
    await _persist();
    notifyListeners();
  }

  Future<void> remove(MediaKind kind, int id) async {
    _entries.remove('${kind.name}:$id');
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    await _persist();
    notifyListeners();
  }

  /// Titles that share genres with [seed] genre ids/names.
  static List<MediaItem> suggestFrom({
    required Iterable<int> genreIds,
    required Iterable<String> genreNames,
    required List<MediaItem> pool,
    Set<String> excludeKeys = const {},
    int limit = 16,
  }) {
    final ids = genreIds.toSet();
    final names = {
      for (final n in genreNames) n.toLowerCase().trim(),
    }..removeWhere((e) => e.isEmpty);

    if (ids.isEmpty && names.isEmpty) {
      return pool
          .where((m) => !excludeKeys.contains(m.dedupeKey))
          .take(limit)
          .toList();
    }

    final scored = <(MediaItem, int)>[];
    for (final item in pool) {
      if (excludeKeys.contains(item.dedupeKey)) continue;
      var score = 0;
      for (final g in item.genreIds) {
        if (ids.contains(g)) score += 3;
      }
      for (final n in item.genreNames) {
        if (names.contains(n.toLowerCase().trim())) score += 2;
      }
      if (score > 0) scored.add((item, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return b.$1.voteAverage.compareTo(a.$1.voteAverage);
    });
    return [for (final s in scored.take(limit)) s.$1];
  }
}

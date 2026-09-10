enum MediaKind { movie, tv }

enum CatalogOrigin { elo, tmdb, trakt, merged }

/// One playable source from the licensed catalog API.
class PlaySource {
  const PlaySource({
    required this.url,
    this.label = 'Player',
    this.quality,
    this.source,
    this.server,
  });

  final String url;
  final String label;
  final String? quality;
  final String? source; // m3u8 | iframe
  final int? server;

  bool get isHls {
    final s = (source ?? '').toLowerCase();
    final u = url.toLowerCase();
    return s == 'm3u8' ||
        u.contains('.m3u8') ||
        u.contains('getm3u8') ||
        u.contains('/live/');
  }

  bool get isIframe {
    final s = (source ?? '').toLowerCase();
    return s == 'iframe' || (!isHls && url.startsWith('http'));
  }

  String get menuLabel {
    final parts = <String>[
      label,
      if (quality != null && quality!.isNotEmpty) quality!,
      if (isHls) 'HLS' else 'Web',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'label': label,
        if (quality != null) 'quality': quality,
        if (source != null) 'source': source,
        if (server != null) 'server': server,
      };

  factory PlaySource.fromJson(Map<String, dynamic> json) {
    return PlaySource(
      url: (json['url'] ?? '').toString(),
      label: (json['translator'] ?? json['label'] ?? 'Player').toString(),
      quality: json['quality']?.toString(),
      source: json['source']?.toString(),
      server: json['server'] is int
          ? json['server'] as int
          : int.tryParse('${json['server'] ?? ''}'),
    );
  }

  static List<PlaySource> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <PlaySource>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final s = PlaySource.fromJson(Map<String, dynamic>.from(e));
      if (s.url.isNotEmpty) out.add(s);
    }
    return out;
  }

  LiveStreamSource toLiveSource() => LiveStreamSource(
        url: url,
        quality: quality,
        feed: label,
      );
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.kind,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.releaseDate,
    this.genreIds = const [],
    this.genreNames = const [],
    this.players = const [],
    this.year,
    this.tmdbId,
    this.catalogOrigin = CatalogOrigin.elo,
    this.createdAt,
  });

  final int id;
  final String title;
  final MediaKind kind;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final List<int> genreIds;
  final List<String> genreNames;
  final List<PlaySource> players;
  final int? year;
  final int? tmdbId;
  final CatalogOrigin catalogOrigin;
  final DateTime? createdAt;

  String get dedupeKey => '${kind.name}:$id';

  bool get hasPlayableSource => players.any((p) => p.url.isNotEmpty);

  List<PlaySource> get hlsPlayers => players.where((p) => p.isHls).toList();
  List<PlaySource> get playable {
    final hls = hlsPlayers;
    if (hls.isNotEmpty) return hls;
    return players;
  }

  MediaItem copyWith({
    int? id,
    String? title,
    MediaKind? kind,
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    String? releaseDate,
    List<int>? genreIds,
    List<String>? genreNames,
    List<PlaySource>? players,
    int? year,
    int? tmdbId,
    CatalogOrigin? catalogOrigin,
    DateTime? createdAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      voteAverage: voteAverage ?? this.voteAverage,
      releaseDate: releaseDate ?? this.releaseDate,
      genreIds: genreIds ?? this.genreIds,
      genreNames: genreNames ?? this.genreNames,
      players: players ?? this.players,
      year: year ?? this.year,
      tmdbId: tmdbId ?? this.tmdbId,
      catalogOrigin: catalogOrigin ?? this.catalogOrigin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MediaItem.fromElo(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'movie').toString().toLowerCase();
    final kind = type == 'serial' || type == 'tv' ? MediaKind.tv : MediaKind.movie;
    final ratings = json['ratings'];
    double vote = 0;
    if (ratings is Map) {
      final imdb = ratings['imdb'];
      if (imdb is Map && imdb['rating'] is num) {
        vote = (imdb['rating'] as num).toDouble();
      }
    }
    final genres = <String>[];
    final genreIds = <int>[];
    final rawGenres = json['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map) {
          final name = g['name']?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
          final id = int.tryParse('${g['id'] ?? ''}');
          if (id != null) genreIds.add(id);
        }
      }
    }
    final year = json['year'] is int
        ? json['year'] as int
        : int.tryParse('${json['year'] ?? ''}');
    final title = (json['title_en'] ??
            json['title_ru'] ??
            json['title'] ??
            'Untitled')
        .toString();
    final tmdbRaw = json['tmdb_id'] ?? json['tmdb'];
    final tmdbId = tmdbRaw is int
        ? tmdbRaw
        : int.tryParse('${tmdbRaw ?? ''}');
    return MediaItem(
      id: json['kinopoisk_id'] as int? ??
          int.tryParse('${json['kinopoisk_id'] ?? json['id'] ?? 0}') ??
          0,
      title: title,
      kind: kind,
      overview: (json['description'] ?? json['overview'] ?? '').toString(),
      posterPath: (json['poster'] ?? json['poster_url'])?.toString(),
      backdropPath: (json['poster'] ?? json['poster_url'])?.toString(),
      voteAverage: vote,
      releaseDate: year != null ? '$year' : null,
      genreIds: genreIds,
      genreNames: genres,
      players: PlaySource.listFromJson(json['player'] ?? json['players']),
      year: year,
      tmdbId: tmdbId,
      catalogOrigin: CatalogOrigin.elo,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  factory MediaItem.fromTmdb(Map<String, dynamic> json, MediaKind kind) {
    final id = json['id'] as int? ?? int.tryParse('${json['id'] ?? 0}') ?? 0;
    final title = (json['title'] ?? json['name'] ?? 'Untitled').toString();
    final date = (json['release_date'] ?? json['first_air_date'])?.toString();
    final year = date != null && date.length >= 4
        ? int.tryParse(date.substring(0, 4))
        : null;
    final genres = <String>[];
    final genreIds = <int>[];
    final rawGenres = json['genre_ids'] ?? json['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is int) {
          genreIds.add(g);
        } else if (g is Map) {
          final name = g['name']?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
          final gid = int.tryParse('${g['id'] ?? ''}');
          if (gid != null) genreIds.add(gid);
        }
      }
    }
    return MediaItem(
      id: id,
      title: title,
      kind: kind,
      overview: (json['overview'] ?? '').toString(),
      posterPath: json['poster_path']?.toString(),
      backdropPath: json['backdrop_path']?.toString(),
      voteAverage: (json['vote_average'] is num)
          ? (json['vote_average'] as num).toDouble()
          : 0,
      releaseDate: date,
      genreIds: genreIds,
      genreNames: genres,
      year: year,
      tmdbId: id,
      catalogOrigin: CatalogOrigin.tmdb,
    );
  }
}

class MediaDetail extends MediaItem {
  const MediaDetail({
    required super.id,
    required super.title,
    required super.kind,
    super.overview,
    super.posterPath,
    super.backdropPath,
    super.voteAverage,
    super.releaseDate,
    super.genreIds,
    super.genreNames,
    super.players,
    super.year,
    super.tmdbId,
    super.catalogOrigin,
    super.createdAt,
    this.runtime,
    this.genres = const [],
    this.seasons = const [],
    this.trailerKey,
    this.imdbId,
    this.tagline = '',
  });

  final int? runtime;
  final List<String> genres;
  final List<TvSeason> seasons;
  final String? trailerKey;
  final String? imdbId;
  final String tagline;

  factory MediaDetail.fromItem(MediaItem item, {int? runtime}) {
    return MediaDetail(
      id: item.id,
      title: item.title,
      kind: item.kind,
      overview: item.overview,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      voteAverage: item.voteAverage,
      releaseDate: item.releaseDate,
      genreIds: item.genreIds,
      genreNames: item.genreNames,
      players: item.players,
      year: item.year,
      tmdbId: item.tmdbId,
      catalogOrigin: item.catalogOrigin,
      createdAt: item.createdAt,
      runtime: runtime,
      genres: item.genreNames,
    );
  }

  factory MediaDetail.fromTmdb(Map<String, dynamic> json, MediaKind kind) {
    final base = MediaItem.fromTmdb(json, kind);
    final genres = <String>[];
    final rawGenres = json['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres) {
        if (g is Map && g['name'] != null) genres.add(g['name'].toString());
      }
    }
    String? trailer;
    final videos = json['videos'];
    if (videos is Map && videos['results'] is List) {
      for (final v in videos['results'] as List) {
        if (v is Map &&
            (v['site']?.toString().toLowerCase() == 'youtube') &&
            (v['type']?.toString().toLowerCase() == 'trailer')) {
          trailer = v['key']?.toString();
          break;
        }
      }
    }
    final seasons = <TvSeason>[];
    final rawSeasons = json['seasons'];
    if (rawSeasons is List) {
      for (final s in rawSeasons) {
        if (s is Map) {
          final sn = s['season_number'];
          if (sn is int && sn > 0) {
            seasons.add(
              TvSeason(
                id: s['id'] as int? ?? sn,
                name: (s['name'] ?? 'Season $sn').toString(),
                seasonNumber: sn,
                episodeCount: s['episode_count'] as int? ?? 0,
                posterPath: s['poster_path']?.toString(),
              ),
            );
          }
        }
      }
    }
    final runtime = kind == MediaKind.movie
        ? (json['runtime'] is int ? json['runtime'] as int : null)
        : null;
    final imdb = json['imdb_id']?.toString();
    return MediaDetail(
      id: base.id,
      title: base.title,
      kind: kind,
      overview: base.overview,
      posterPath: base.posterPath,
      backdropPath: base.backdropPath,
      voteAverage: base.voteAverage,
      releaseDate: base.releaseDate,
      genreIds: base.genreIds,
      genreNames: genres.isNotEmpty ? genres : base.genreNames,
      year: base.year,
      tmdbId: base.id,
      catalogOrigin: CatalogOrigin.tmdb,
      runtime: runtime,
      genres: genres.isNotEmpty ? genres : base.genreNames,
      seasons: seasons,
      trailerKey: trailer,
      imdbId: imdb,
      tagline: (json['tagline'] ?? '').toString(),
    );
  }
}

class TvSeason {
  const TvSeason({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
    this.posterPath,
  });

  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final String? posterPath;
}

class TvEpisode {
  const TvEpisode({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeNumber,
    this.overview = '',
    this.stillPath,
    this.runtime,
    this.players = const [],
  });

  final int id;
  final String name;
  final int seasonNumber;
  final int episodeNumber;
  final String overview;
  final String? stillPath;
  final int? runtime;
  final List<PlaySource> players;

  factory TvEpisode.fromTmdb(Map<String, dynamic> json, int season) {
    return TvEpisode(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? 'Episode').toString(),
      seasonNumber: season,
      episodeNumber: json['episode_number'] as int? ?? 0,
      overview: (json['overview'] ?? '').toString(),
      stillPath: json['still_path']?.toString(),
      runtime: json['runtime'] is int ? json['runtime'] as int : null,
    );
  }
}

class Genre {
  const Genre({required this.id, required this.name});
  final int id;
  final String name;
}

/// One playable live feed (quality / mirror) for a channel.
class LiveStreamSource {
  const LiveStreamSource({
    required this.url,
    this.quality,
    this.feed,
    this.userAgent,
    this.referrer,
  });

  final String url;
  final String? quality;
  final String? feed;
  final String? userAgent;
  final String? referrer;

  String get label {
    final parts = <String>[
      if (quality != null && quality!.isNotEmpty) quality!,
      if (feed != null && feed!.isNotEmpty) feed!,
    ];
    return parts.isEmpty ? 'Stream' : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (quality != null) 'quality': quality,
        if (feed != null) 'feed': feed,
        if (userAgent != null) 'userAgent': userAgent,
        if (referrer != null) 'referrer': referrer,
      };

  factory LiveStreamSource.fromJson(Map<String, dynamic> json) {
    return LiveStreamSource(
      url: (json['url'] ?? '').toString(),
      quality: json['quality']?.toString(),
      feed: json['feed']?.toString(),
      userAgent: (json['userAgent'] ?? json['user_agent'])?.toString(),
      referrer: (json['referrer'] ?? json['referer'])?.toString(),
    );
  }
}

class LiveChannel {
  const LiveChannel({
    required this.id,
    required this.name,
    required this.category,
    this.streamUrl,
    this.logoUrl,
    this.isLive = true,
    this.quality,
    this.userAgent,
    this.referrer,
    this.subtitle,
    this.countryCode,
    this.countryName,
    this.sources = const [],
  });

  final String id;
  final String name;
  final String category;
  final String? streamUrl;
  final String? logoUrl;
  final bool isLive;
  final String? quality;
  final String? userAgent;
  final String? referrer;
  final String? subtitle;
  final String? countryCode;
  final String? countryName;
  final List<LiveStreamSource> sources;

  List<LiveStreamSource> get selectableSources {
    if (sources.isNotEmpty) return sources;
    final url = streamUrl;
    if (url == null || url.isEmpty) return const [];
    return [
      LiveStreamSource(
        url: url,
        quality: quality,
        userAgent: userAgent,
        referrer: referrer,
      ),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        if (streamUrl != null) 'streamUrl': streamUrl,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'isLive': isLive,
        if (quality != null) 'quality': quality,
        if (userAgent != null) 'userAgent': userAgent,
        if (referrer != null) 'referrer': referrer,
        if (subtitle != null) 'subtitle': subtitle,
        if (countryCode != null) 'countryCode': countryCode,
        if (countryName != null) 'countryName': countryName,
        'sources': [for (final s in sources) s.toJson()],
      };

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final sources = <LiveStreamSource>[];
    if (rawSources is List) {
      for (final s in rawSources) {
        if (s is Map) {
          final src = LiveStreamSource.fromJson(Map<String, dynamic>.from(s));
          if (src.url.isNotEmpty) sources.add(src);
        }
      }
    }
    return LiveChannel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Channel').toString(),
      category: (json['category'] ?? 'Other').toString(),
      streamUrl: json['streamUrl']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
      isLive: json['isLive'] != false,
      quality: json['quality']?.toString(),
      userAgent: json['userAgent']?.toString(),
      referrer: json['referrer']?.toString(),
      subtitle: json['subtitle']?.toString(),
      countryCode: json['countryCode']?.toString(),
      countryName: json['countryName']?.toString(),
      sources: sources,
    );
  }
}
